# ADR-001: Start from Monolithic Architecture with Scalable Backend Decomposition

## Status

Accepted

## Context

We have an existing, mature R package ([ichimomo/frasyr](https://github.com/ichimomo/frasyr)) that encapsulates the all calculation logic for stock assessment evaluation.
This package performs complex assessment calculations and has been refined through years of domain expertise.
However, we lack any web application layer to operationalize this computation engine.

Business requirements drive architectural choices:

- **Scientists need parallel scenario computation**: Scientists as assesment operator must be able to run multiple stock evaluation scenarios with different parameters simultaneously to compare outcomes. This is critical for decision-making.
- **Stakeholder satisfaction depends on throughput**: The ability to process diverse evaluation scenarios efficiently will directly impact customer satisfaction and business viability.
- **No budget for complete rewrite**: We cannot afford to rewrite the mature R package in another language. We must leverage this existing investment.

Current constraints:

- Team is resource-constrained; building a complex, distributed system from scratch is not feasible
- Domain model for the broader evaluation business is still evolving
- We need to ship results quickly while maintaining architecture quality

## Decision

We will **start with a monolithic architecture** that leverages the existing R package, while designing for eventual backend decomposition through API contracts.

Concretely:

1. **Build a monolithic application** where:
   - Frontend (Next.js + TypeScript) coexists with backend services (Plumber + R package)
   - Single deployment unit minimizes operational overhead
   - Shared data layer supports cohesive feature delivery

2. **Maintain strict API boundaries** between:
   - Frontend (BFF) and backend (Plumber), using OpenAPI contracts
   - This boundary becomes the "seam" along which we may later decompose

3. **Design for future scalability decomposition**:
   - Plumber API becomes substrate for independent backend services
   - Frontend integration remains unchanged (contract preserved)
   - As load or bounded contexts demand, extract Plumber compute service independently
   - Enable horizontal scaling of computation without refactoring frontend

## Consequences

### Positive

- Leverages existing R package investment without costly rewrite
- Enables rapid feature delivery with minimal operational complexity
- Clear API boundary (OpenAPI) allows future backend decomposition without frontend changes
- Team can focus on domain modeling and feature delivery instead of infrastructure
- Shared codebase and deployment simplify coordinated development and testing
- Supports parallel scenario computation within single application

### Negative

- Monolith may grow to include unrelated concerns as business expands
- Single points of failure in early stages (though mitigated by clear boundaries)
- Scaling the compute layer requires scaling the entire application initially
- Potential for unclear ownership of features that span frontend and backend

### Mitigation

- Use directory structure and explicit API definitions to enforce separation of concerns
- Define OpenAPI schema as the frontend-backend contract; treat as a public API
- Monitor system growth and identify compute bottlenecks; plan extraction point if discovered
- Document bounded contexts as they emerge from business requirements and experimentation
- Build with multi-scenario compute at the core; expect to extract compute service later if throughput becomes the constraint

## Alternatives Considered

### Microservices from Day One

- Cleanly separates concerns and enables independent scaling
- Requires significant operational infrastructure (containerization, service discovery, inter-service communication, monitoring)
- Demands early clarity on bounded contexts, but domain model is still evolving
- Adds deployment complexity without immediate value
- **Rejected**: Premature optimization that would consume resources better spent on feature delivery and domain understanding

### Shiny App (R-based Web Framework)

- Quick path to evaluation UI
- Keeps computation and UI within R ecosystem
- Insufficient for future business application requirements (customer management, workflow orchestration, reporting)
- Difficult to modularize beyond simple computation wrapper
- **Rejected**: Inadequate for long-term business application vision

### Serverless/FaaS (AWS Lambda, Cloud Functions)

- Reduces operational overhead for stateless functions
- R runtime support exists but is not primary use case
- Difficult to manage state and coordinate multi-step workflows
- Vendor lock-in risk
- Parallel scenario computation may incur unpredictable costs at scale
- **Rejected**: Does not align with requirement for efficient parallel computation and cost predictability

## Related Information

- [ADR-002: Backend Technology - Plumber for R Computation Engine](./002-backend-plumber.md)
- [ADR-003: Frontend Technology - Next.js with TypeScript](./003-frontend-nextjs-typescript.md)
- [リファクタリングの大まかな方針を再考した | Rindrics Mumbles](https://rindrics.com/posts/stock-assess-restart/)