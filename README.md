## Lottery with Foundry

A contract to conduct lottery and randomly select a winner.

### User Actions

Users can participate in the lottery by paying an entry fee.

### Lottery Results

The contract selects multiple winners

Position | Prize Percentage
-|-
1<sup>st</sup> | 20%
2<sup>nd</sup> | 15%
3<sup>rd</sup> | 10%
4<sup>th</sup> to 10<sup>th</sup> | 8%

If a raffle has minimum 10 players, then anyone can pick the winners by paying a fee of >=4% of the total pool of the raffle.

### Setup Requirements

* [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Setup Process

* Run `make install` to import all the required packages.
* Run `make build` to compile the contracts.

### Testing

* Run `make test-it` to run all the tests.
* Run `make test-v` to run tests with logs.
* Run `make coverage-report` to get a report of missing points in the tests in [coverage.md](./coverage.md).