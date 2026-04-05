---
title: "<% tp.file.title %>"
summary: ""
type: project
tech_stack: []
repo: ""
source_path: ""
status: active
created: <% tp.date.now("YYYY-MM-DD") %>
last_active: <% tp.date.now("YYYY-MM-DD") %>
---

# <% tp.file.title %>

## Objective

<% tp.file.cursor() %>

## Tech Stack

-

## Quick Start

```bash
cd <source_path>
npm install
npm run dev
```

## Architecture

(link to Architecture.md when available)

## Recent Notes

```dataview
TABLE summary, type, created
FROM "Projects/<% tp.file.title %>"
WHERE file.name != "_index"
SORT created DESC
```
