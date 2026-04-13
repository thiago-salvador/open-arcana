# Domain Scoping (2 rules)

## DS-1. Domain-specific responses

When the user asks about a specific domain (work, personal, content, research, partnerships), the response MUST contain ONLY items from that domain.

- Alerts, pending items, and memories from other domains are **irrelevant even if they are urgent**
- Urgency is not relevance. An urgent alert from a personal project is not a work priority
- Filter by: domain tag in the alert, domain field in frontmatter, vault folder, project memory file

## DS-2. Alerts with domain tags

Alerts in `00-Dashboard/alerts.md` carry a domain tag (e.g., `` `work` ``, `` `personal` ``). When answering domain-specific questions:
1. Read the domain tag of each alert
2. Include ONLY alerts from the requested domain
3. Alerts without a domain tag (legacy) or with domain `personal`: include only if the question is about "personal" or does not specify a domain
4. When in doubt about an alert's domain, **do not include** rather than include incorrectly
