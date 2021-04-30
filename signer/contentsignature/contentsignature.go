package contentsignature // import "github.com/mozilla-services/autograph/signer/contentsignature"

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/asn1"
	"hash"
	"io"

	"github.com/mozilla-services/autograph/signer"

	"github.com/pkg/errors"
)

const (
	// Type of this signer is 'contentsignature'
	Type = "contentsignature"

	// P256ECDSA defines an ecdsa content signature on the P-256 curve
	P256ECDSA = "p256ecdsa"

	// P256ECDSABYTESIZE defines the bytes length of a P256ECDSA signature
	P256ECDSABYTESIZE = 64

	// P384ECDSA defines an ecdsa content signature on the P-384 curve
	P384ECDSA = "p384ecdsa"

	// P384ECDSABYTESIZE defines the bytes length of a P384ECDSA signature
	P384ECDSABYTESIZE = 96

	// P521ECDSA defines an ecdsa content signature on the P-521 curve
	P521ECDSA = "p521ecdsa"

	// P521ECDSABYTESIZE defines the bytes length of a P521ECDSA signature
	P521ECDSABYTESIZE = 132

	// SignaturePrefix is a string preprended to data prior to signing
	SignaturePrefix = "Content-Signature:\x00"
)

// ContentSigner implements an issuer of content signatures
type ContentSigner struct {
	signer.Configuration
	priv crypto.PrivateKey
	pub  crypto.PublicKey
	rand io.Reader
}

// New initializes a ContentSigner using a signer configuration
func New(conf signer.Configuration) (s *ContentSigner, err error) {
	s = new(ContentSigner)
	s.ID = conf.ID
	s.Type = conf.Type
	s.PrivateKey = conf.PrivateKey
	s.X5U = conf.X5U
	if conf.Type != Type {
		return nil, fmt.Errorf("contentsignature: invalid type %q, must be %q", conf.Type, Type)
	}
	if conf.ID == "" {
		return nil, fmt.Errorf("contentsignature: missing signer ID in signer configuration")
	}
	if conf.PrivateKey == "" {
		return nil, fmt.Errorf("contentsignature: missing private key in signer configuration")
	}
	s.rand = conf.GetRand()
	s.priv, s.pub, s.PublicKey, err = conf.GetKeys()
	if err != nil {
		return nil, errors.Wrap(err, "contentsignature: failed to retrieve signer")
	}
	switch s.pub.(type) {
	case *ecdsa.PublicKey:
	default:
		return nil, fmt.Errorf("contentsignature: invalid private key algorithm, must be ecdsa")
	}
	s.Mode = s.getModeFromCurve()
	return
}

// Config returns the configuration of the current signer
func (s *ContentSigner) Config() signer.Configuration {
	return signer.Configuration{
		ID:         s.ID,
		Type:       s.Type,
		Mode:       s.Mode,
		PrivateKey: s.PrivateKey,
		PublicKey:  s.PublicKey,
		X5U:        s.X5U,
	}
}

// SignData takes input data, templates it, hashes it and signs it.
// The returned signature is of type ContentSignature and ready to be Marshalled.
func (s *ContentSigner) SignData(input []byte, options interface{}) (signer.Signature, error) {
	if len(input) < 10 {
		return nil, fmt.Errorf("contentsignature: refusing to sign input data shorter than 10 bytes")
	}
	alg, hash := makeTemplatedHash(input, s.Mode)
	sig, err := s.SignHash(hash, options)
	sig.(*ContentSignature).storeHashName(alg)
	return sig, err
}

// hash returns the templated sha384 of the input data. The template adds
// the string "Content-Signature:\x00" before the input data prior to
// calculating the sha384.
//
// The name of the hash function is returned, followed by the hash bytes
func makeTemplatedHash(data []byte, curvename string) (alg string, out []byte) {
	templated := make([]byte, len(SignaturePrefix)+len(data))
	copy(templated[:len(SignaturePrefix)], []byte(SignaturePrefix))
	copy(templated[len(SignaturePrefix):], data)
	var md hash.Hash
	switch curvename {
	case P384ECDSA:
		md = sha512.New384()
		alg = "sha384"
	case P521ECDSA:
		md = sha512.New()
		alg = "sha512"
	default:
		md = sha256.New()
		alg = "sha256"
	}
	md.Write(templated)
	return alg, md.Sum(nil)
}

// SignHash takes an input hash and returns a signature. It assumes the input data
// has already been hashed with something like sha384
func (s *ContentSigner) SignHash(input []byte, options interface{}) (signer.Signature, error) {
	if len(input) != 32 && len(input) != 48 && len(input) != 64 {
		return nil, fmt.Errorf("contentsignature: refusing to sign input hash. length %d, expected 32, 48 or 64", len(input))
	}
	var err error
	csig := new(ContentSignature)
	csig = &ContentSignature{
		Len:  getSignatureLen(s.Mode),
		Mode: s.Mode,
		X5U:  s.X5U,
		ID:   s.ID,
	}

	asn1Sig, err := s.priv.(crypto.Signer).Sign(rand.Reader, input, nil)
	if err != nil {
		return nil, errors.Wrap(err, "contentsignature: failed to sign hash")
	}
	var ecdsaSig ecdsaAsn1Signature
	_, err = asn1.Unmarshal(asn1Sig, &ecdsaSig)
	if err != nil {
		return nil, errors.Wrap(err, "contentsignature: failed to parse signature")
	}
	csig.R = ecdsaSig.R
	csig.S = ecdsaSig.S
	csig.Finished = true
	return csig, nil
}

// getSignatureLen returns the size of an ECDSA signature issued by the signer,
// or -1 if the mode is unknown
//
// The signature length is double the size size of the curve field, in bytes
// (each R and S value is equal to the size of the curve field).
// If the curve field it not a multiple of 8, round to the upper multiple of 8.
func getSignatureLen(mode string) int {
	switch mode {
	case P256ECDSA:
		return P256ECDSABYTESIZE
	case P384ECDSA:
		return P384ECDSABYTESIZE
	case P521ECDSA:
		return P521ECDSABYTESIZE
	}
	return -1
}

// getSignatureHash returns the name of the hash function used by a given mode,
// or an empty string if the mode is unknown
func getSignatureHash(mode string) string {
	switch mode {
	case P256ECDSA:
		return "sha256"
	case P384ECDSA:
		return "sha384"
	case P521ECDSA:
		return "sha512"
	}
	return ""
}

// getModeFromCurve returns a content signature algorithm name, or an empty string if the mode is unknown
func (s *ContentSigner) getModeFromCurve() string {
	switch s.pub.(*ecdsa.PublicKey).Params().Name {
	case "P-256":
		return P256ECDSA
	case "P-384":
		return P384ECDSA
	case "P-521":
		return P521ECDSA
	default:
		return ""
	}
}

// GetDefaultOptions returns nil because this signer has no option
func (s *ContentSigner) GetDefaultOptions() interface{} {
	return nil
}
