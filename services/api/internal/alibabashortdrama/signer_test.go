package alibabashortdrama

import "testing"

func TestSignHMACMD5SortsAllParameters(t *testing.T) {
	params := map[string]string{
		"foo":     "1",
		"bar":     "2",
		"foo_bar": "3",
		"foobar":  "4",
	}

	got, err := sign(params, "secret", "hmac")
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	const want = "26C775E5D0EB124C248184BFA79CA514"
	if got != want {
		t.Fatalf("sign = %q, want %q", got, want)
	}
}

func TestSignRejectsUnsupportedMethod(t *testing.T) {
	if _, err := sign(map[string]string{"foo": "1"}, "secret", "sha1"); err == nil {
		t.Fatal("expected unsupported sign method error")
	}
}
