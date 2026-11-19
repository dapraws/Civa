# Civa

A personal career workspace for macOS. Keep your experience, education, projects, achievements, and skills in one Career Profile, then build as many resumes from it as you need, each one tailored to a job, without retyping anything.

Civa is local first: your data stays on your Mac. It has no account and no server.

## Features

- **Career Profile.** Professional and organizational experience, education, projects, achievements, certifications, and skills, each with dates, results, and proof links.
- **Resumes.** Build a Master resume from your profile, then tailored copies for each job. Live PDF preview, templates (Classic, MIT, Harvard, Tech), and a formatting ribbon for fonts, spacing, and margins. Exports text-based PDFs that applicant tracking systems can read.
- **Import.** Start from an existing CV, a LinkedIn PDF, or your LinkedIn data export. You review every record before it's added.
- **Applications.** Track each job from Wishlist to Offer, with its description, the resume you sent, and attached documents.
- **Documents.** Keep certificates, transcripts, and portfolio files once, link them to any record, and drag them straight into a job site's upload box.
- **Ovi.** A small owl that notices common resume mistakes as you work, like tiny fonts, duty-style bullets, or missing contact details, and explains each tip with its source (MIT, Harvard, NACE).
- **Workspaces.** Separate workspaces for different people on the same Mac, each with its own data.
- **AI, your way.** Optional Claude Desktop integration: Claude reads only the categories you allow, and nothing changes until you apply its suggestion. Or use Copy Prompt to take a ready-made prompt to any AI.

## Requirements

- macOS 26 or later
- Xcode 26 or later to build

## Building

1. Clone the repository and open `Civa.xcodeproj`.
2. Optional: for company and school logos, copy `Civa/Config/Secrets.example.plist` to `Civa/Config/Secrets.plist` and add a Brandfetch client ID. Without it, Civa shows initials.
3. Select the **Civa** scheme and run.

Debug builds start on sample data, so testing never touches your own. Switch in Settings → Developer.

Run the tests with:

```bash
xcodebuild test -project Civa.xcodeproj -scheme Civa -destination 'platform=macOS' -only-testing:CivaTests
```

## Releasing

`scripts/release.sh` archives a Release build, signs it with your Developer ID, notarizes it, and makes a DMG in `build/release/`. See the comments at the top of the script for the one-time setup.

## Privacy

Everything you enter stays on your Mac. Civa connects to the internet only to look up company and school logos (sending just the name you type, and you can turn this off in Settings), and, if you set it up, to talk to Claude Desktop on the same Mac.

## License

Civa's code is licensed under the [GNU General Public License v3.0](LICENSE). The Civa name, the app icon, and the Ovi artwork are not covered by that license: all rights reserved.

Young Serif is licensed under the SIL Open Font License 1.1. Sparkle is licensed under the MIT License.
