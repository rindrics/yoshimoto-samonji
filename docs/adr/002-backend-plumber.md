# ADR-002: Backend Technology - Plumber for R Computation Engine

## Status

Accepted

## Context

The stock assessment evaluation system has a mature R-based computation engine that performs complex financial calculations.
We are building a monolithic application that will eventually grow into a full business application platform for evaluation management.

Key requirements:
- Leverage existing R computation assets without rewriting
- Provide HTTP API interface for frontend integration
- Minimize boilerplate infrastructure code
- Enable automated OpenAPI documentation generation
- Support future expansion into a comprehensive evaluation business application

We considered alternatives like building a Python/Node.js wrapper or migrating to a different language, but these would discard years of domain expertise encoded in the R implementations.

## Decision

We will use **[Plumber](https://www.rplumber.io/)** as the backend framework to expose the R computation engine as an HTTP API.

Plumber is an RStudio-developed framework that:
- Transforms R functions into REST APIs with minimal code
- Automatically generates OpenAPI 3.0 documentation
- Maintains the R ecosystem for statistical and financial computations
- Provides straightforward routing and request/response handling
- Integrates seamlessly with existing R packages and workflows

## Consequences

### Positive

- Preserves investment in R-based computation logic
- Reduces friction between computation and API layers
- OpenAPI schema enables frontend code generation and type safety
- Simple to add new endpoints as business logic evolves
- Natural fit for statistical/financial domain

### Negative

- Team needs to learn/maintain Plumber ecosystem
- R runtime management and deployment considerations
- Less mature ecosystem compared to Node.js/Python frameworks
- Performance characteristics may require optimization for high-load scenarios

### Mitigation

- Plumber handles only API routing and request validation; core computations remain in optimized R
- OpenAPI documentation ensures API contract clarity
- Future evaluation of performance bottlenecks can inform caching strategies

## Alternatives Considered

### Python FastAPI / Flask

- Would require rewriting computation logic
- More popular ecosystem, but loses R domain expertise
- Rejected: High cost of rewriting vs. modest ecosystem gains

### Node.js Express

- Similar drawbacks as Python
- Would separate computation from business logic
- Rejected: Same rationale as Python

### AWS Lambda / Serverless

- Premature optimization for unproven load patterns
- Adds operational complexity in early stages
- Rejected: Monolithic architecture preferred initially

## Related ADRs

- [ADR-003: Frontend Technology - Next.js with TypeScript](./003-frontend-nextjs-typescript.md)
