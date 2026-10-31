# Testing

This document details how GN is tested.

> [!NOTE]
> Before testing, make sure to bootstrap and launch GN.

## Relevant files
| Path              | Description  |
| :---------------- | :----------- |
| gn-test           | Entrypoint to run all automated tests |
| test/             | Helper scripts, suites and configuration |
| test/syntax-check | Best-effort syntax check for scripts |
| test/link-check   | Crawl the local web interface with linkchecker |
