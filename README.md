# NFT Permissions

This contract allows devs to add authorization capabilities to their own contracts, with a very flexible permission system. The contract creates the
concept of a "position", that underlying contracts can use to represent ownership. This could be ownership of funds or more complex ideas. Each
position is represented by an NFT, that can be transferred by the owner.

Whoever owns a position, has full permissions over the position. However, the owner can also grant/revoke specific permissions to other accounts.
Permissions are represented by a number, so it's up to each dev to determine the values used to represent each permission in their system.

Finally, the owner can grant permissions by interacting directly with the contract, but they can also be granted via signature.

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ pnpm lint
```

### Test

Run the tests:

```sh
$ forge test
```

## License

This project is licensed under MIT.

## Audits

This project has been audited by [Omniscia](https://twitter.com/Omniscia_sec). You can see the report [here](https://omniscia.io/reports/mean-finance-nft-permission-system-65536361239be600181362f3/).
