/// API contract version this client build speaks. Bump it when the app starts
/// relying on a new backend contract. This is the unit of client/server
/// compatibility — it is compared against the backend's `minClientVersion` to
/// decide force-update. Deliberately NOT `PackageInfo.buildNumber`: that is a
/// commit counter (and is 1 in dev), so it cannot express an API contract.
const int kClientApiVersion = 1;

/// True when this client is too old for the backend and must be force-updated.
/// Pure so it can be unit-tested and mutation-checked in isolation.
bool isClientOutdated(int clientApiVersion, int minClientVersion) =>
    clientApiVersion < minClientVersion;
