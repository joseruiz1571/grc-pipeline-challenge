# METADATA
# title: AC-3 - Access Enforcement (GCP Cloud Storage)
# description: Every google_storage_bucket must hard-block public access.
# custom:
#   control_id: AC-3
#   framework: nist-800-53
#   severity: critical
#   remediation: Set public_access_prevention = "enforced" and uniform_bucket_level_access = true.
package compliance.ac3_gcp

import rego.v1

# GCP needs no reference trick for AC-3: access enforcement is a plain VALUE on
# the bucket itself, not a separate resource. Deny any bucket that does not both
# enforce public-access-prevention and require uniform (IAM-only) access.

deny contains msg if {
	some bucket in buckets
	bucket.values.public_access_prevention != "enforced"
	msg := sprintf(
		"AC-3: %s does not enforce public access prevention (is %q). Remediation: set public_access_prevention = \"enforced\".",
		[bucket.address, object.get(bucket.values, "public_access_prevention", "unset")],
	)
}

deny contains msg if {
	some bucket in buckets
	bucket.values.uniform_bucket_level_access != true
	msg := sprintf(
		"AC-3: %s does not require uniform bucket-level access. Remediation: set uniform_bucket_level_access = true.",
		[bucket.address],
	)
}

buckets contains resource if {
	walk(input.planned_values.root_module, [_, resource])
	is_object(resource)
	resource.type == "google_storage_bucket"
}
