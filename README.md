# PostgreSQL Schema for Testing

#### What

Contains various psotgresql schemas, with a way to deploy all of them in a single postgresql docker container locally.

### Purpose

This is just a combination of random schemas, which are perfect for your performance, load, or any other testing you may have with Postgresql instance. Some most notable things in here:

- Pagila
- AdventureWorks _(caveat: schema only, no data)_
- Table with 1600 columns
- Schema with > 100 tables


### How to use

```bash
## Clone the repo
git clone git@github.com:Navusas/postgres-test-schema.git
cd postgres-test-schema/

## Use docker-compose#
docker-compose up
```

Connect using this connection string:

```bash
Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=123456
```

Alternatively, you can run it using Docker:

```bash
# Create volume
docker volume create pgdata
# Run container
docker run -d --name pagila \
       -v $(pwd):/docker-entrypoint-initdb.d/ \
       -v pgdata:/var/lib/postgresql/data \
       -p 5432:5432 \
       -e POSTGRES_PASSWORD=123456 \
       -e POSTGRES_USER=postgres \
       postgres:13.2
```


### Mentions
- [devrimgunduz/pagila](https://github.com/devrimgunduz/pagila)
- [lorint/AdventureWorks-for-Postgres](https://github.com/lorint/AdventureWorks-for-Postgres)