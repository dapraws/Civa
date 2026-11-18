# Changelog

Every Civa release, newest first. Versions follow [Semantic Versioning](https://semver.org):
a new feature raises the middle number, a fix-only release raises the last one.

## [1.1.0] - 2026-11-19

### Added

- **Updates inside Civa.** Choose Civa → Check for Updates…, or let Civa check about once a
  day. You read what's new and install with one click; Civa relaunches on the new version.
- **Review page.** Everything waiting on you sits in one list: Claude's suggestions and drafts,
  and imported records you haven't confirmed yet. Its count shows in the sidebar and on Civa's
  Dock icon.
- **A notification when Claude sends something** while Civa is in the background.
- **Update Header from Profile** in the resume editor copies your name, headline, contact
  details, and links from Personal Information.
- **Claude can do more in Civa**, still only as suggestions you apply:
  - Edit any text in your Career Profile: role, organization, degree, thesis, issuer, skill
    names, and more, so it can also translate a record field by field.
  - Edit your headline and summary directly.
  - Add Career Profile records and skills to a resume, take entries out, reorder sections and
    entries, and make a resume your Master Resume.
  - Draft resumes with the records and sections in the order it chooses.
  - Send records with the fields their category has: issuer, test score, issue and expiry
    dates, credential links, field of study, and grade.
  - See which of its suggestions you applied or dismissed.
  - See the titles of records you haven't confirmed yet. Their details stay private until you
    confirm them.

### Changed

- A suggestion from Claude for an education, achievement, certification, or skill record opens
  on that record.

### Fixed

- A long title no longer pushes its date to the next line. The date stays on the first line
  and the title wraps before it, in every template.
- Links in a resume header open the whole address, even when it wraps onto a second line.
  Headers print links in their short form, like `linkedin.com/in/name`.
- An invisible character from a PDF photo no longer sits in front of names. Civa removes it
  from imported text and from profiles imported earlier.
- Claude reads grades as resumes print them (3.30, not 3,30).

## [1.0.0] - 2026-11-18

### Added

- First release: Career Profile, resumes in four ATS-safe templates, job applications,
  documents, Ovi's tips, and Claude Desktop integration.
