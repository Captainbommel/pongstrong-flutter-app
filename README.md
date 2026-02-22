# pongstrong

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Team Import (CSV)

Teams can be imported via a CSV file in the Admin Panel. The CSV file can be
created and edited in any spreadsheet application (Excel, Google Sheets, etc.)
and exported as `.csv`.

### With groups (for *Groups & Knockouts* mode)

The first column is the group name (or number), followed by team name,
member 1, and member 2:

```csv
group,name,member1,member2
Gruppe A,Smash Bros,Alice,Bob
Gruppe A,Paddle Kings,Carol,Dave
Gruppe B,Net Ninjas,Eve,Frank
Gruppe B,Spin Masters,Grace,Heidi
```

Numbers work too — they are grouped by value:

```csv
group,name,member1,member2
1,Smash Bros,Alice,Bob
1,Paddle Kings,Carol,Dave
2,Net Ninjas,Eve,Frank
2,Spin Masters,Grace,Heidi
```

### Without groups (flat list)

If the tournament style does not use groups, you can omit the group column:

```csv
name,member1,member2
Smash Bros,Alice,Bob
Paddle Kings,Carol,Dave
Net Ninjas,Eve,Frank
Spin Masters,Grace,Heidi
```

> **Tip:** The header row is required. Fields containing commas or quotes
> should be wrapped in double-quotes following the RFC 4180 convention
> (e.g. `"O'Brien, Jr."`).
