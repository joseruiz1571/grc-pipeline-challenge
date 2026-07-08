Last week the pipeline promised the evidence was real. This week nobody has to take my word for it.

Week 4 of the 6-Week GRC Pipeline Challenge. The CI gate from week 3 now bundles its evidence, hashes it, and signs it with Cosign on every run. Then I wrote a verify script that anyone can run against the bundle: recompute the hash, check the signature, print CHAIN INTACT only if both hold.

The part worth explaining is why there is no key.

The old model: generate a private key, store it as a secret, guard it, rotate it, hope it never leaks. Anyone who gets that key can forge your evidence. And that same person probably has admin on the account they are supposed to be audited by.

Cosign keyless flips this. The pipeline proves its identity with a short-lived OIDC token from GitHub. Sigstore issues a certificate that lives for minutes, signs, and records the event in a public transparency log. The certificate encodes which repo and which workflow produced the signature. There is nothing to steal, and the proof lives outside my infrastructure. Even someone with full admin on my cloud account cannot forge it.

I learned this the honest way: keyless signing refused to work from my laptop session, because the identity check demands a live login it could not fake. The property that made it inconvenient for me is the property that makes it trustworthy for an auditor.

Then the tamper test. Copy the signed bundle, append a single byte, run the verify script. It fails on integrity instantly, and the signature check would have failed independently on the same byte. Run it against the real bundle: CHAIN INTACT.

One byte. Chain of custody is not a policy statement. It is math.

Also moved the gate's pass or fail decision to the last step of the workflow, so a failing run still gets signed. A failed run is exactly the evidence you most want preserved.

Week 5: the native cloud controls that watch the account itself.

GRC Engineering Club #GRCEngClubChallenge #GRCEngineering
