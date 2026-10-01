# Moving the NSS post into the Quarto website

The draft is `portfolio/nss-dashboard.md`. It is written to become a Quarto blog post.

## 1. Fill in the TODOs
- The three `TODO` key insights in the Executive summary.
- `TODO-link` (×2): the dashboard link (Publish to web, a PDF or a video) and the GitHub repo URL.
- Check the key-insight numbers against the dashboard. They are the defaults, with no slicers applied.

## 2. Take the screenshots
In Power BI Desktop, clear all slicers and switch to reading view. Take each screenshot with Windows + Shift + S, cropping to the page, and save it as a PNG about 1600 px wide:
- **Pages:** `overview.png`, `subject.png`, `theme.png`, `student.png`, `priority.png`.
- **Drill-throughs:** `subject-detail.png` and `question-detail.png`. Drill through from a chart first, so the page shows a selected subject or question.
- **Star schema:** `star-schema.png`, from Model view, with the tables arranged neatly.

## 3. Copy into the website project
Assuming a standard Quarto blog layout (`posts/<slug>/index.qmd`):

```
<website>/posts/nss-dashboard/
├── index.qmd          ← nss-dashboard.md, renamed
└── images/
    ├── overview.png, subject.png, theme.png, student.png, priority.png
    ├── subject-detail.png, question-detail.png
    └── star-schema.png
```

- Rename the `.md` file to `index.qmd`. The front matter (`title`, `description`, `date`, `categories`, `image`) is already in the format the Quarto blog listing reads.
- `image: images/overview.png` becomes the thumbnail on the blog listing page.
- If your site uses a different folder, such as `projects/`, put it there instead and make sure the listing in that folder's `index.qmd` includes it.

## 4. Optional extras
- **Embed the live report** (only if you used Publish to web). Replace the "View the dashboard" link, or add a block under "The dashboard":
  ```
  <iframe title="NSS dashboard" width="100%" height="560" src="PUBLISH-TO-WEB-URL" frameborder="0" allowFullScreen="true"></iframe>
  ```
- **Lightbox on screenshots:** add `lightbox: true` to the front matter so readers can click an image to enlarge it.
- **Hide the TOC** if the post feels crowded: `toc: false`.

## 5. Preview and publish
```
quarto preview
```
Check the listing thumbnail, the image captions and the links. Then publish the way your site normally does (`quarto publish`, or push to the repo if it deploys from GitHub).
