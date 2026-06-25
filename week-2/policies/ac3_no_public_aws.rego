# METADATA
# title: AC-3 - Access Enforcement (AWS S3 public access block)
# description: Every aws_s3_bucket must have a public access block with all four flags true.
# custom:
#   control_id: AC-3
#   framework: nist-800-53
#   severity: critical
#   remediation: Add aws_s3_bucket_public_access_block referencing the bucket, all four flags true.
package compliance.ac3_aws

import rego.v1

# Deny any aws_s3_bucket that lacks a public access block with all four flags
# true. Two halves: match the block to its bucket by REFERENCE (configuration),
# then read the four flag VALUES from planned_values by the block's address.

deny contains msg if {
	some bucket in input.configuration.root_module.resources
	bucket.type == "aws_s3_bucket"
	addr := sprintf("aws_s3_bucket.%s", [bucket.name])
	not compliant_pab(addr)
	msg := sprintf(
		"AC-3: %s has no public access block with all four flags true. Remediation: add aws_s3_bucket_public_access_block referencing %s with block_public_acls, block_public_policy, ignore_public_acls and restrict_public_buckets all true.",
		[addr, addr],
	)
}

# True when a fully-locked public access block references the given bucket.
compliant_pab(bucket_addr) if {
	some pab in input.configuration.root_module.resources
	pab.type == "aws_s3_bucket_public_access_block"
	some ref in pab.expressions.bucket.references
	reference_addr(ref) == bucket_addr

	pab_addr := sprintf("aws_s3_bucket_public_access_block.%s", [pab.name])
	some pv in input.planned_values.root_module.resources
	pv.address == pab_addr
	pv.values.block_public_acls == true
	pv.values.block_public_policy == true
	pv.values.ignore_public_acls == true
	pv.values.restrict_public_buckets == true
}

# Collapse "aws_s3_bucket.primary.id" -> "aws_s3_bucket.primary".
reference_addr(ref) := concat(".", array.slice(split(ref, "."), 0, 2))
