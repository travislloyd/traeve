# traeve.com

Personal website for Travis Lloyd.  This site is built using the Jekyll framework to be hosted on Github pages.  It also contains a utility script, `publish.rb`, that will handle publishing Hardly Relevant mixes.

## Website

`jekyll serve` is all you need to get the site up and running on localhost.  Jekyll integrates nicely with Github pages, so to deploy all you need to do is push changes to the master branch and the site will be live.  Currently it is hosted at http://traeve.com.

## Publish Script

This script performs several steps associated with publishing a Hardly Relevant mix:

1. Writes metadata to the mix MP3 files.
2. Generates MKV (video) files from the MP3s and cover images.
3. Uploads the MP3 files to Google Drive and gets public download links.
4. Uploads the MKV files to Youtube and creates a new playlist.
5. Creats a jekyll blog post that references the newly uploaded files. 
6. Generates text that can be used as a template for a facebook post and email message about the mix.

Currently the script is configured to upload the Youtube videos as "private" videos, which allows for a manual review before making them available to subscribers.  The jekyll blog post also needs to be pushed to the master branch before it will be availale on the live site.

### Setup

Integration with Google Drive and Youtube expects two config files, one at `config/google.json` of the format:
```
{
  "client_id": "xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com",
  "client_secret": "xxxxxxxxxxxxxxxxxxxxxxxx",
  "scope": [
    "https://www.googleapis.com/auth/drive",
    "https://spreadsheets.google.com/feeds/"
  ]
}
```
And one at `config/youtube_secret.json` that you can generate by using the google developer portal (full instructions [here](https://support.google.com/googleapi/answer/6158849)).  Once these files exist, running the publish script will guide you through granting your workflow access to your Google Drive and Youtube accounts.  If you run into issues configuring Google Drive, See full instructions [here](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md), but note that you'll need to add the "scope" field of the config file, which is not mentioned in those instructions. 

### Usage

Run `bin/publish.rb <PATH_TO_MANIFEST>` to publish a Hardly Relevant mix described by a manifest file. The manifests are located in `/manifests` and `/manifests/manifestSchema.json` is the schema definition.

### Output

This script will produce an output JSON file that references all the created assets.  The file will be in the `/output` folder and will be named with the manifest's volume number.

### Testing

Run `rspec` from the base directory to run the test suite.
