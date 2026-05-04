.PHONY: dev build test format lint clean docker-build docker-run

# Run the `neonlaw.org` website locally on port 3001.
dev:
	swift run App

# Compile every product in the package.
build:
	swift build

# Run the full Swift Testing suite.
test:
	swift test

# Auto-format every Swift source in-place.
format:
	swift format -i -r .

# Strict lint — matches the CI check.
lint:
	swift format lint --strict --recursive --parallel --no-color-diagnostics .

# Remove build artifacts.
clean:
	rm -rf .build .swiftpm

# Build the production container image locally.
docker-build:
	docker build -t web:local .

# Run the production container and expose it on port 3001 so it can be
# exercised with `curl http://localhost:3001/`.
docker-run:
	docker run --rm -p 3001:8080 web:local
