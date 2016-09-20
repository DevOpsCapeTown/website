# Website for Cape Town DevOps

This is the website for Cape Town DevOps ([devops.capetown](https://devops.capetown)). Contributions are welcome.

## Contributing

This site is built using the [Jekyll site generator](https://jekyllrb.com/) and hosted on Amazon S3 with Amazon CloudFront. 
Travis CI handles builds and runs for each latest commit pushed to the repository. To contribute changes:

1. Create a branch from the latest `develop` branch, commit your changes and open a PR against the `develop` branch.
2. Once changes are accepted into the `develop` branch, they can be merged into the `staging` branch by a maintainer (this can be done with another PR, or manually with git).
3. Once your changes reflect on https://staging.devops.capetown, and are reviewed, they can be made live by a maintainer by merging the `staging` branch into the `production` branch (again, manually or with a PR).

## Deployment

There are two special branches - `staging` and `production`. When changes are pushed to these branches, the `deploy.sh`
script, which is run by Travis, syncs the built site to S3 and refreshes CloudFront and DNS configurations.

Deployed changes may take a few minutes to appear due to edge caching by CloudFront.

