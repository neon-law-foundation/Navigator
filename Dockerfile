# syntax=docker/dockerfile:1.7

# Stage 1 — builder. Static Swift stdlib so the runtime only needs glibc,
# libstdc++, libgcc, and CA roots.
FROM swift:6.3-noble AS builder

WORKDIR /build

COPY Package.swift Package.resolved ./
RUN swift package resolve

COPY Sources ./Sources
COPY Plugins ./Plugins
# SPM validates every declared testTarget path even for `--product App`.
COPY Tests ./Tests

RUN swift build -c release --static-swift-stdlib --product App \
    && strip --strip-unneeded .build/release/App

# Stage 2 — distroless runtime. `cc-debian13:nonroot` ships glibc 2.41 +
# libstdc++ + CA roots; bookworm (debian12) does not carry the GLIBCXX
# symbols the Swift 6.3 binary needs.
FROM gcr.io/distroless/cc-debian13:nonroot AS runtime

WORKDIR /app

COPY --chown=nonroot:nonroot Public ./Public
COPY --from=builder --chown=nonroot:nonroot /build/.build/release/App ./App
COPY --from=builder --chown=nonroot:nonroot /build/.build/release/Navigator_App.resources ./Navigator_App.resources

EXPOSE 8080

ENTRYPOINT ["/app/App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
