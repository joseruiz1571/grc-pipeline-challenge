# METADATA
# title: CM-6 - Configuration Settings (AWS required tags)
# description: Taggable resources must carry the four required compliance tags.
# custom:
#   control_id: CM-6
#   framework: nist-800-53
#   severity: medium
#   remediation: Add the missing tags or rely on provider default_tags.
package compliance.cm6_aws

import rego.v1

required := {"Project", "Environment", "ManagedBy", "ComplianceScope"}

# Deny any taggable resource missing one or more required tags. Tags are plain
# VALUES (no reference trick needed): prefer the merged values.tags_all set
# (what provider default_tags produces) and fall back to values.tags.

deny contains msg if {
	some resource in taggable_resources
	missing := required - present_tags(resource)
	count(missing) > 0
	msg := sprintf(
		"CM-6: %s is missing required tags: %s. Remediation: add the missing tags or enable provider default_tags.",
		[resource.address, concat(", ", sort(missing))],
	)
}

# Every resource that actually carries tags, found anywhere in the plan tree
# (root module plus any nested child_modules). walk() recurses for free.
taggable_resources contains resource if {
	walk(input.planned_values.root_module, [_, resource])
	is_object(resource)
	resource.address
	is_taggable(resource)
}

is_taggable(resource) if resource.values.tags_all
is_taggable(resource) if resource.values.tags

# The set of tag keys present on a resource (tags_all wins when both exist).
present_tags(resource) := {key | some key, _ in resource.values.tags_all}

present_tags(resource) := {key | some key, _ in resource.values.tags} if {
	not resource.values.tags_all
}
