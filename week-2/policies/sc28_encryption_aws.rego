# METADATA
# title: SC-28 - Encryption at Rest (AWS S3)
# description: Every aws_s3_bucket must have a matching server-side encryption configuration.
# custom:
#   control_id: SC-28
#   framework: nist-800-53
#   severity: high
#   remediation: Add aws_s3_bucket_server_side_encryption_configuration referencing the bucket.
package compliance.sc28_aws

import rego.v1

# Deny any aws_s3_bucket with no matching server-side encryption configuration.
#
# Match by REFERENCE, not value: at plan time the bucket's real name carries a
# random suffix that does not exist yet, so we never compare names. Instead we
# read the static resource ADDRESS ("aws_s3_bucket.primary") from the
# configuration block, and check whether any encryption resource's
# .expressions.bucket.references points back at that same address.

deny contains msg if {
	some bucket in input.configuration.root_module.resources
	bucket.type == "aws_s3_bucket"
	addr := sprintf("aws_s3_bucket.%s", [bucket.name])
	not has_encryption(addr)
	msg := sprintf(
		"SC-28: %s has no server-side encryption configuration. Remediation: add aws_s3_bucket_server_side_encryption_configuration referencing %s.",
		[addr, addr],
	)
}

# True when some encryption resource references the given bucket address.
has_encryption(bucket_addr) if {
	some enc in input.configuration.root_module.resources
	enc.type == "aws_s3_bucket_server_side_encryption_configuration"
	some ref in enc.expressions.bucket.references
	reference_addr(ref) == bucket_addr
}

# Collapse a reference like "aws_s3_bucket.primary.id" down to its resource
# address "aws_s3_bucket.primary" (first two dot-separated segments).
reference_addr(ref) := concat(".", array.slice(split(ref, "."), 0, 2))
