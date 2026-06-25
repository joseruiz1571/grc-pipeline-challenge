# METADATA
# title: SC-28 - Encryption at Rest (GCP Cloud Storage)
# description: Every google_storage_bucket must have effective encryption at rest.
# custom:
#   control_id: SC-28
#   framework: nist-800-53
#   severity: high
#   remediation: GMEK is on by default; if an encryption block is declared it must name a KMS key.
package compliance.sc28_gcp

import rego.v1

# SC-28 is structurally different on GCP than on AWS. GCS encrypts every object
# at rest by default with a Google-managed key (GMEK) -- there is no separate
# encryption resource to match by reference, and you cannot turn encryption off.
# So a plain "bucket exists" check would be a no-op gate.
#
# The realistic failure mode is a HALF-configured customer-managed key (CMEK):
# someone adds an encryption block but leaves default_kms_key_name empty. This
# policy passes default GMEK buckets and denies that broken-CMEK case.
#
# To require CMEK on every bucket (stricter interpretation), flip the rule:
#   deny if a bucket has no encryption.default_kms_key_name at all.

deny contains msg if {
	some bucket in buckets
	some enc in bucket.values.encryption
	trim_space(object.get(enc, "default_kms_key_name", "")) == ""
	msg := sprintf(
		"SC-28: %s declares an encryption block with no KMS key. Remediation: set encryption.default_kms_key_name, or remove the block to use the default Google-managed key (GMEK).",
		[bucket.address],
	)
}

buckets contains resource if {
	walk(input.planned_values.root_module, [_, resource])
	is_object(resource)
	resource.type == "google_storage_bucket"
}
