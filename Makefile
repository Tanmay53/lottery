install:
	forge install

build:
	forge build

coverage-report:
	forge coverage --report debug > coverage.md

test-it:
	forge test

test-v:
	forge test -vv
