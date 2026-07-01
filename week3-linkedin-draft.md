A policy you run on your laptop catches your own mistakes. A policy you run in CI catches everyone's, forever.

Week 3 of the 6-Week GRC Pipeline Challenge. The three Rego namespaces from last week are now a GitHub Actions gate. Every pull request to main triggers it. Any violation fails the job.

The tricky part was the exit code.

Conftest exits non-zero on a violation. But if you redirect its output to capture the JSON evidence, you have to explicitly propagate that exit code. If you do not, you get a gate that records violations and still passes. That is not a gate. It is a log.

One other thing: `if: always()` on the evidence upload. The artifact has to survive the failure. A compliance system that destroys its records the moment something goes wrong has the causality backwards.

Two pull requests in the repo. One green, one red. Branch protection on main. The red one cannot be merged until the violation is fixed, by anyone.

That is the sentence. Not "the review caught it." The pipeline blocked it.

Week 4: the evidence this gate produces gets signed. Once signed, nobody can quietly edit it.

GRC Engineering Club #GRCEngClubChallenge #GRCEngineering
