# Setting up Vercel Web Preview Deployments

This guide explains how to configure Vercel for automatic web preview deployments on pull requests.

## Prerequisites

- A Vercel account (free tier is sufficient)
- Admin access to this GitHub repository

## Setup Steps

### 1. Create a Vercel Project

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click "Add New..." → "Project"
3. Import this GitHub repository (`remrama/worn`)
4. Configure the project:
   - **Framework Preset**: Other
   - **Build Command**: Leave empty (handled by GitHub Actions)
   - **Output Directory**: `build/web`
   - **Install Command**: Leave empty (handled by GitHub Actions)
5. Click "Deploy" (this initial deployment can be ignored)

### 2. Get Vercel Credentials

You'll need three pieces of information from Vercel:

#### Get Vercel Token
1. Go to [Vercel Account Settings → Tokens](https://vercel.com/account/tokens)
2. Click "Create Token"
3. Name it "GitHub Actions - Worn"
4. Select appropriate scope (Full Account recommended for simplicity)
5. Copy the token (you won't be able to see it again)

#### Get Organization ID
1. Go to [Vercel Account Settings](https://vercel.com/account)
2. Under "Your ID", copy the string (starts with `team_` or similar)

#### Get Project ID
1. Go to your Vercel project settings
2. Navigate to "General" tab
3. Copy the "Project ID" value

### 3. Add Secrets to GitHub

1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Click "New repository secret" and add these three secrets:
   - `VERCEL_TOKEN`: Paste the token from step 2.1
   - `VERCEL_ORG_ID`: Paste the organization ID from step 2.2
   - `VERCEL_PROJECT_ID`: Paste the project ID from step 2.3

### 4. Test the Workflow

1. Create a new pull request to the `main` branch
2. The workflow will:
   - Build the Flutter web app
   - Deploy it to Vercel
   - Comment on the PR with the preview URL
3. Each new commit to the PR will trigger a new deployment

## How It Works

- The `.github/workflows/deploy-web-preview.yml` workflow runs on every PR to `main`
- It builds the Flutter web app using `flutter build web`
- The built files in `build/web/` are deployed to Vercel
- A comment is automatically posted to the PR with the preview URL
- The preview is accessible at a unique URL for each PR
- Previews are automatically cleaned up when PRs are closed/merged

## Troubleshooting

### Workflow fails with "VERCEL_TOKEN not found"
- Ensure you've added all three secrets to GitHub (step 3)
- Secret names must match exactly: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`

### Build fails during "flutter build web"
- Check that the web platform is properly configured
- Run `flutter build web` locally to identify issues
- Ensure all dependencies support web platform

### Preview URL shows blank page
- Check browser console for errors
- Verify that `--base-href=/` is correct for your Vercel deployment
- Check that all assets are loading correctly

## Alternative: Native Vercel GitHub Integration

Instead of using GitHub Actions, you can use Vercel's native GitHub integration:

1. During project import, enable "Production Branch" and "Preview Branches"
2. Vercel will automatically:
   - Deploy on every push to main
   - Create preview deployments for PRs
   - Comment preview URLs on PRs
3. This approach requires adding a custom `installCommand` to `vercel.json` to install Flutter

The GitHub Actions approach (described above) gives more control over the build process and is recommended for this project.

## Notes

- Web previews are best for reviewing UI/UX changes
- Some mobile-specific features may not work on web (this is expected)
- Preview deployments are temporary and will be deleted after PR closure
- Each PR gets a unique, stable URL that updates with new commits
