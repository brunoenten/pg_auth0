
# pg_auth0: PostgreSQL Extension for Auth0 API

`pg_auth0` is a PostgreSQL extension that integrates Auth0's Management API directly into your PostgreSQL database. This allows you to manage Auth0 resources such as users, roles, and permissions using SQL queries within your database environment.

## Features

- **Seamless Integration**: Execute Auth0 Management API operations directly from PostgreSQL.
- **Simplified Management**: Manage Auth0 entities like users and roles using familiar SQL commands.
- **Enhanced Security**: Leverage PostgreSQL's security features to control access to Auth0 management functions.

## Prerequisites

Before installing `pg_auth0`, ensure you have the following:

- PostgreSQL 9.6 or higher
- Auth0 account with Management API access
- Auth0 Management API token

## Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/brunoenten/pg_auth0.git
   ```

2. **Navigate to the Directory**:

   ```bash
   cd pg_auth0
   ```

3. **Build and Install the Extension**:

   ```bash
   make
   sudo make install
   ```

4. **Load the Extension in PostgreSQL**:

   ```sql
   CREATE EXTENSION auth0;
   ```

## Configuration

After installation, configure the extension to communicate with the Auth0 Management API:

1. **Set Auth0 Domain and Token**:

   ```sql
   SELECT auth0.set_domain('your-auth0-domain');
   SELECT auth0.set_token('your-auth0-management-api-token');
   ```

   Replace `'your-auth0-domain'` with your Auth0 domain (e.g., `example.auth0.com`) and `'your-auth0-management-api-token'` with your Auth0 Management API token.

## Usage

Once configured, you can perform various Auth0 Management API operations. For example, to retrieve a list of users:

```sql
SELECT * FROM auth0.get_users();
```

This will return a set of users from your Auth0 tenant.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your enhancements or bug fixes.

## License

This project is licensed under the GPL-3.0 License. See the [LICENSE.txt](LICENSE.txt) file for details.

## Acknowledgments

Special thanks to the [Auth0](https://auth0.com) team for their comprehensive authentication and authorization platform.

---

*Note: This extension is a community-driven project and is not officially supported by Auth0.* 
