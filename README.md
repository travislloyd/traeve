# traeve.com

Personal website for Travis Lloyd.  This site is built using the Jekyll framework to be hosted on Github pages.  It also contains a utility script, publish.rb, that will handle publishing Hardly Relevant mixes.

## Setup

Integration with Google Drive and Youtube apects a config file at `config/google.json` of the format:
```
{
  "client_id": "xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com",
  "client_secret": "xxxxxxxxxxxxxxxxxxxxxxxx",
  "scope": [
    "https://www.googleapis.com/auth/drive",
    "https://spreadsheets.google.com/feeds/",
    "https://www.googleapis.com/auth/youtube.upload"
  ]
}
```
Once this file exists, running the publish script will guide you through granting your workflow access to your Google Drive and Youtube accounts.  See full instructions [here](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md), but note that you'll need to add the "scope" field of the config file, which is not mentioned in those instructions. 

## Usage

Run `bin/publish <PATH_TO_MANIFEST>` to publish a Hardly Relevant mix described by a manifest file. The manifests are located in /manifests and /manifests/manifestSchema.json is the schema definition.

## Testing

Run `rspec` from the base directory to run the test suite.
