# ADR-003: Frontend and BFF Architecture - Next.js with TypeScript

## Status

Accepted

## Context

We are building a frontend for a stock assessment evaluation system that will eventually grow into a comprehensive business application managing the entire evaluation lifecycle.

The system integration requires:
- **Frontend**: User-facing evaluation interface with domain-driven architecture
- **BFF (Backend for Frontend)**: Authentication, session management, response transformation, request validation
- **Backend**: Plumber API exposing R computation engine

Key requirements:
- Implement domain-driven frontend architecture aligned with business concepts
- Support type safety across frontend-backend integration
- Enable incremental growth from computation UI to full business application
- Provide clear API contracts via OpenAPI integration
- Maintain developer productivity as complexity scales
- Minimize operational overhead for BFF layer

Prior experience with the stock assessment state management experiment demonstrated that careful domain modeling at the frontend layer is critical for a system that will grow beyond a simple UI wrapper around computations.

## Decision

We will use **Next.js with TypeScript** as a full-stack framework, leveraging its Route Handlers to implement both the frontend UI and the Backend for Frontend (BFF) layer in a single deployment unit.

**Frontend (Next.js Pages/App Router):**
- TypeScript React components for evaluation interface
- Server-side rendering and static generation where appropriate
- Client-side state management for interactive features
- File-based routing for pages and layouts

**BFF (Next.js Route Handlers):**
- HTTP routes in `/app/api` for frontend consumption
- Authentication and session management
- Response transformation and reshaping from Plumber API
- Error handling normalization
- Cross-cutting concerns (logging, audit, rate limiting)

**Why Next.js:**
- Single language ecosystem (JavaScript/TypeScript) reduces cognitive load
- Full-stack framework eliminates need for separate BFF service
- Built-in Route Handlers for BFF implementation
- TypeScript support across entire application (frontend and BFF)
- Excellent tooling for OpenAPI schema integration (code generation)
- Unified deployment and development experience
- File-based routing and built-in optimization features
- Middleware support for authentication and cross-cutting concerns

**Type Safety:**
- TypeScript integration with Plumber OpenAPI schema
- Code generation for frontend client types from OpenAPI spec
- Self-documenting code through explicit type definitions
- Early detection of API contract violations
- Improved refactoring safety across codebase

## Consequences

### Positive

- Strong type safety across frontend-backend boundary
- Single deployment unit reduces operational overhead
- BFF logic colocated with frontend code, reducing cognitive distance
- OpenAPI schema can drive TypeScript client code generation
- Single language ecosystem (JavaScript/TypeScript) reduces cognitive load
- Next.js ecosystem provides solutions for routing, state management, auth
- Future business logic can be modeled as TypeScript domain objects
- Built-in Route handlers enable BFF pattern without separate deployment
- No network overhead between frontend and BFF
- Easier to evolve frontend requirements without infrastructure changes

### Negative

- Requires TypeScript and modern JavaScript expertise on team
- Initial setup overhead compared to simpler frameworks
- Trade-off between type safety and rapid prototyping in early phases
- Bundle size considerations if not carefully managed
- Couples BFF concerns with frontend deployment initially
- If BFF grows significantly, may need refactoring to separate service later
- Shared memory/CPU resources with frontend (must monitor resource usage)

### Mitigation

- Use code generation for OpenAPI types to reduce boilerplate
- Establish domain modeling guidelines and clear directory structure (`/app/api` for BFF)
- Monitor bundle size metrics; use Next.js built-in optimizations
- Establish clear separation between frontend code and BFF logic via directory conventions
- Document the contract between BFF and Plumber via OpenAPI schema
- Use environment variables to externalize Plumber endpoint URL for future flexibility
- Monitor performance; plan migration path if BFF and frontend resources diverge significantly

## Evolution Path

**Current Phase:**
- All code (frontend + BFF) deployed together
- Clean separation via directory structure (`/app/pages` and `/app/api`)
- OpenAPI schema as contract between BFF and Plumber

**Future Phase (If Needed):**
- If BFF grows significantly or compute load becomes asymmetric:
  1. Extract BFF to dedicated `/services/bff` directory
  2. Evaluate containerizing BFF separately
  3. Potentially migrate to standalone service (Node.js/Express/Fastify)
  4. Maintain OpenAPI schema as contract during migration
- Frontend continues to use Next.js; no changes required

## Alternatives Considered

### Shiny App (R-based)

- Quick path to evaluation UI within R ecosystem
- Insufficient for future business application requirements
- Limited to R ecosystem conventions
- Difficult to implement domain-driven architecture
- **Rejected**: Inadequate for long-term business application vision

### Vue.js + Vite (Frontend) + Express (BFF)

- More lightweight than Next.js
- Forces separation of frontend and BFF codebases
- Requires managing two separate services and deployments
- More operational complexity
- **Rejected**: Unnecessary overhead for monolithic phase

### Plain React + Express

- Separates frontend and BFF layers unnecessarily
- Adds deployment complexity
- No file-based routing or built-in optimizations
- **Rejected**: More operational burden without corresponding benefit

### SvelteKit

- Good alternative full-stack framework
- Smaller ecosystem than Next.js
- Good TypeScript support
- **Rejected**: Next.js ecosystem and maturity preferred for business application longevity

## Related ADRs

- [ADR-001: Monolithic Architecture with Scalable Backend Decomposition](./001-start-from-monolith.md)
- [ADR-002: Backend Technology - Plumber for R Computation Engine](./002-backend-plumber.md)