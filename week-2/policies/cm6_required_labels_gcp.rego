# METADATA
# title: CM-6 - Configuration Settings (GCP required labels)
# description: Taggable resources must carry the four required compliance labels.
# custom:
#   control_id: CM-6
#   framework: nist-800-53
#   severity: medium
#   remediation: Add the missing labels (GCP uses labels, not tags).
package compliance.cm6_gcp

import rego.v1

# CM-6 is the same control as AWS, but GCP calls them "labels" and the keys are
# lowercase snake_case. Same shape, different vocabulary -- which is the whole
# point: the control is portable, the resource type is not.
required := {"project", "environment", "managed_by", "compliance_scope"}

deny contains msg if {
	some resource in labelable_resources
	missing := required - present_labels(resource)
	count(missing) > 0
	msg := sprintf(
		"CM-6: %s is missing required labels: %s. Remediation: add the missing labels.",
		[resource.address, concat(", ", sort(missing))],
	)
}

labelable_resources contains resource if {
	walk(input.planned_values.root_module, [_, resource])
	is_object(resource)
	resource.address
	resource.values.labels
}

present_labels(resource) := {key | some key, _ in resource.values.labels}
