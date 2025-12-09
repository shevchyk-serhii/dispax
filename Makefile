.PHONY: fmt fmt-watch dev test clean

# Format all code
fmt:
	sbt fmtAll

# Watch and format on changes
fmt-watch:
	sbt fmtWatch

# Start development server
dev:
	ENV=dev sbt run

# Start integration environment
int:
	ENV=int sbt run

# Start production
prod:
	ENV=prod sbt run

# Run tests
test:
	sbt test

# Clean build
clean:
	sbt clean

# Full rebuild
rebuild: clean
	sbt compile