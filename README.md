# Stash::Merritt

[![Build Status](https://travis-ci.org/CDLUC3/stash-merritt.svg?branch=master)](https://travis-ci.org/CDLUC3/stash-merritt)
[![Code Climate](https://codeclimate.com/github/CDLUC3/stash-merritt.svg)](https://codeclimate.com/github/CDLUC3/stash-merritt)
[![Inline docs](http://inch-ci.org/github/CDLUC3/stash-merritt.svg)](http://inch-ci.org/github/CDLUC3/stash-merritt)

Packaging and
[SWORD 2.0](http://swordapp.github.io/SWORDv2-Profile/SWORDProfile.html)
deposit module for submitting
[Stash](https://github.com/CDLUC3/stash_engine) datasets to
[Merritt](http://www.cdlib.org/uc3/merritt/).

## Submission process

The `Stash::Merritt::SubmissionJob` class does the following:

1. if no identifier is present, mint a new DOI with EZID
   (using the [ezid-client](https://github.com/duke-libraries/ezid-client) gem)
   and assign it to the resource
1. generate a ZIP package containing:

   | filename | purpose |
   | -------- | ------- |
   | `stash-wrapper.xml` | [Stash wrapper](https://github.com/CDLUC3/stash-wrapper), including [Datacite 4](https://schema.datacite.org/meta/kernel-4.0/) XML |
   | `mrt-datacite.xml` | [Datacite 3](https://schema.datacite.org/meta/kernel-3/) XML, for Merritt internal use. |
   | `mrt-oaidc.xml` | Dublin Core metadata, packaged in [oai_dc](https://www.openarchives.org/OAI/openarchivesprotocol.html#dublincore) format for [OAI-PMH](https://www.openarchives.org/OAI/openarchivesprotocol.html) compliance |
   | `mrt-dataone-manifest.txt` | legacy [DataONE manifest](http://cdluc3.github.io/dash/release-criteria/)* |
   | `mrt-delete.txt` | list of files to be deleted in this version, if any |

   \* Note that the DataONE manifest is generated for all tenants, not just DataONE.

1. using the [stash-sword](https://github.com/CDLUC3/stash-sword) gem, submit the
   package to Merritt via [SWORD 2.0](http://swordapp.github.io/SWORDv2-Profile/SWORDProfile.html);
   update the `download_uri` and `update_uri` of the resource if not present
1. set the resource `version_zipfile`
1. again via [ezid-client](https://github.com/duke-libraries/ezid-client), update the
   target URL (landing page) and Datacite 3 metadata for the DOI
1. clean up uploads and other temporary files
1. returns a successful `SubmissionResult`

If at any point one of these steps fails, the job exits with a failed `SubmissionResult`.

## Development

### Dependencies

stash-merritt expects to find the [stash_engine](https://github.com/CDLUC3/stash_engine) and 
[stash_datacite](https://github.com/CDLUC3/stash_datacite) source locally under
a sister directory `stash_engines`:

```
┬── stash-merritt
└── stash_engines
    ├── stash_datacite
    └── stash_engine
```

### Test database creation

For compatibility with Travis, you need

1. a local MySQL installation
2. a `travis@localhost` user with no password
3. a `stash_merritt` database
4. `travis` to have all privileges on that database

This should look something like:

```
$ mysql -u root
mysql> create user 'travis'@'localhost';
mysql> create database stash_merritt character set UTF8mb4 collate utf8mb4_bin;
mysql> use stash_merritt;
mysql> grant all on stash_merritt.* to 'travis'@'localhost';
```
