# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/elasticsearch
[![Docker Repository on Quay.io](https://quay.io/repository/aptible/elasticsearch/status)](https://quay.io/repository/aptible/elasticsearch)

Elasticsearch on Docker.

## Installation and Usage

    docker pull quay.io/aptible/elasticsearch
    docker run quay.io/aptible/elasticsearch

## Advanced Usage

### Creating a database user with password

`TODO`

## Available Tags

* `latest`: Currently Elasticsearch 1.3.2

## Tests

Tests are run as part of the `Dockerfile` build. To execute them separately within a container, run:

    bats test

## Deployment

To push the Docker image to Quay, run the following command:

    make release

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2014 [Aptible](https://www.aptible.com), [Frank Macreery](https://github.com/fancyremarker), and contributors.
