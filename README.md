# fetch_tag
Simple script to create database backup and checkout tag on bellcom drupal projects.

## Usage
### Checkout tag on repo

```
./fetch_tag.sh {tag}
```

This checks out the specified tag, backups the database to the current users home dir, and saves the path of the databasebackup
in the script directory under the name `{tag}.info`

### Restore previous tag and database
```
./fetch_tag.sh restore {tag}
```

This checks out the specified tag, and imports the database specified in the file `{tag}.info` from the script directory.
