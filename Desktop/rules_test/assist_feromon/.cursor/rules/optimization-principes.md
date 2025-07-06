# Code Optimization Principles & Extended Thinking Framework (Python Edition)

## Overview

This document establishes **optimization principles** for projects built with **Python 3.12**, **FastAPI**, **Pydantic v2**, **SQLAlchemy (Async)** and background workers such as **Celery / RQ**. The rules are adapted from the original JavaScript/TypeScript guidelines but all **examples are now in Python** to help you copy‑paste directly into *Cursor*.

## Core Philosophy

> "The best code is **no code**. The second‑best code is code that **already exists and works**."

### The **LEVER** Framework

| Letter | Meaning                             |
| ------ | ----------------------------------- |
| **L**  | **Leverage** existing patterns      |
| **E**  | **Extend** before creating          |
| **V**  | **Verify** through reactivity/tests |
| **E**  | **Eliminate** duplication           |
| **R**  | **Reduce** complexity               |

---

## Extended Thinking Process

Always run through this decision tree *before* you start coding:

```mermaid
graph TD
    A[New Feature Request] --> B{Can existing code handle it?}
    B -->|Yes| C[Extend existing code]
    B -->|No|  D{Can we modify existing patterns?}
    D -->|Yes| E[Adapt and extend]
    D -->|No|  F{Is the new code reusable?}
    F -->|Yes| G[Create abstraction]
    F -->|No|  H[Reconsider approach]
    C --> I[Document extensions]
    E --> I
    G --> J[Create new pattern]
    H --> A
```

---

## Pre‑Implementation Checklist

### 1 · Pattern Recognition (10‑15 min)

```markdown
## Existing Pattern Analysis
- [ ] What similar functionality already exists?
- [ ] Which SQLAlchemy models / repositories handle related data?
- [ ] Which FastAPI routes expose similar info?
- [ ] Which Pydantic schemas cover the same shape?

## Code Reuse Opportunities
- [ ] Can I **extend** an existing table instead of creating a new one?
- [ ] Can I add optional fields to an existing Pydantic model?
- [ ] Can I enhance a service layer function with an extra flag?
- [ ] Can I conditionally branch inside an existing endpoint?
```

### 2 · Complexity Assessment (5‑10 min)

```markdown
## Proposed Solution Complexity
- New lines of code: ___
- New files created: ___
- New DB tables: ___
- New API endpoints: ___

## Optimized Alternative
- Lines **extending** existing code: ___
- Files **modified**: ___
- Fields **added** to existing tables: ___
- Existing endpoints **enhanced**: ___

If the optimized variant costs **< 50 %** of the proposed effort → choose optimization.
```

---

## Architecture Principles

### 1 · Database Schema Extensions

#### ❌ Anti‑Pattern: Creating New Tables

```python
# DON'T – brand‑new table that duplicates user info
class CampaignTracking(Base):
    __tablename__ = "campaign_tracking"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    source: Mapped[str]
    medium: Mapped[str]
    # … 10 more columns
```

*Problems: joins, migrations, sync logic*

#### ✅ Pattern: Extend Existing Table

```python
# DO – extend users table with optional columns
class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str]
    # … other existing fields …

    # ✔️  campaign tracking (optional)
    campaign_source: Mapped[str | None] = mapped_column(String(50), nullable=True)
    invite_code_used: Mapped[str | None] = mapped_column(String(20), nullable=True)
```

*Benefits: data locality, reuse of indexes, fewer joins*

---

### 2 · Query Optimization

#### ❌ Anti‑Pattern: Duplicate Query Logic

```python
# DON'T – three similar queries
async def get_trial_users(session: AsyncSession):
    ...

async def get_active_trials(session: AsyncSession):
    ...

async def get_expiring_trials(session: AsyncSession):
    ...
```

#### ✅ Pattern: Extend Existing Query

```python
# DO – one function with optional filters
async def get_user_status(
    session: AsyncSession,
    *,
    include_trial: bool = False,
    only_expiring: bool = False,
) -> list[UserStatus]:
    q = select(User).where(User.subscription_status == "trialing")
    if only_expiring:
        q = q.where(User.trial_end < datetime.utcnow() + timedelta(days=3))

    rows = await session.scalars(q)
    return [UserStatus.from_orm(u, include_trial=include_trial) for u in rows]
```

---

### 3 · Service‑Layer Extension Instead of New Hooks

(React hooks → service functions / dependency‑injected classes)

```python
# BEFORE – separate services
class TrialService: ...
class CampaignService: ...

# AFTER – unified service
class SubscriptionService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_enriched_status(self, user_id: int) -> UserStatus:
        user = await self.session.get(User, user_id)
        days_remaining = (user.trial_end - datetime.utcnow()).days if user.trial_end else None
        return UserStatus(
            **user.as_dict(),
            should_show_trial_offer=user.is_trialing and days_remaining <= 3,
            campaign_effectiveness=self._calculate_roi(user),
        )
```

---

## Async Task / Worker Optimizations

### 1 · Leverage Celery Retries Instead of Manual Loops

```python
# ❌ DON'T – ad‑hoc retry loop
for _ in range(3):
    try:
        result = requests.post(url, json=payload, timeout=3)
        result.raise_for_status()
        break
    except requests.HTTPError:
        sleep(1)
```

```python
# ✅ DO – let Celery handle retries
@celery.task(bind=True, autoretry_for=(HTTPError,), retry_backoff=True, retry_kwargs={"max_retries": 3})
async def send_webhook(self, payload: dict[str, Any]):
    async with httpx.AsyncClient() as client:
        r = await client.post(url, json=payload, timeout=3)
        r.raise_for_status()
```

### 2 · Batch Operations

```python
# ❌ Sequential database writes
for item in items:
    session.add(item)
    await session.commit()
```

```python
# ✅ Bulk save
session.add_all(items)
await session.commit()
```

---

## Decision Framework – Extend vs Create New

| Criteria                                  | Extend Existing | Create New |
| ----------------------------------------- | --------------- | ---------- |
| Similar data structure exists             | +3              | −3         |
| Can reuse existing indexes                | +2              | −2         |
| Existing queries cover related data       | +3              | −3         |
| API endpoints already expose similar info | +2              | −2         |
| < 50 lines to extend                      | +3              | −3         |
| Would introduce circular deps             | −5              | +5         |
| Completely different domain               | −3              | +3         |

**Score > 5 → Extend · Score < −5 → Create · Otherwise → Investigate deeper**

---

## Three‑Pass Implementation Strategy

1. **Discovery (0 code)** – list every related module/file, mark reuse points.
2. **Design (min. code)** – sketch interface changes, update pydantic models.
3. **Implementation (opt. code)** – add only essential logic, write tests.

---

## Real‑World Example – Trial Flow Optimization

### Before (JS version)

* 4 new tables
* 10+ queries
* 5 React components
* Manual state sync loops

### After (Python version)

* Extended 2 tables (+11 cols)
* Reused 1 repository method (`get_user_status`)
* Leveraged FastAPI dependency injection & `BackgroundTasks`

**Result: 87 % code reduction, faster queries, easier maintenance.**

---

## Performance Optimization Rules

### 1 · Query Efficiency

```python
# ❌ Multiple round‑trips
user = await repo.get_user(user_id)
subscription = await repo.get_subscription(user_id)
usage = await repo.get_usage(user_id)

# ✅ Single aggregated query
status = await repo.get_user_status(user_id, include_usage=True)
```

### 2 · Index Usage

```python
# Use composite index instead of three separate ones
Index("ix_users_subscription_status_campaign", User.subscription_status, User.campaign_source)
```

### 3 • Avoid N+1 in ORM

```python
# Prefetch related entities in one go
stmt = (
    select(User)
    .options(selectinload(User.subscriptions), selectinload(User.usage))
)
users = (await session.scalars(stmt)).all()
```

---

## Anti‑Patterns to Avoid

1. **"Just One More Table" Trap** – Each table ⬆ complexity (joins, migrations).
2. **"Similar But Different" Excuse** – Consider optional params before new function.
3. **"API Mirrors UI" Misstep** – Database design should *not* be driven by UI layouts.

---

## Documentation Requirements

```python
# Clearly explain why you extend instead of create
async def get_user_status(session: AsyncSession, user_id: int) -> UserStatus:
    """OPTIMIZATION: Added campaign fields here instead of separate tracking table.
    Saves joins and keeps data local (see: trial‑optimization‑2025‑07‑01).
    """
    ...
```

---

## Success Metrics

| Metric                           | Target                          |
| -------------------------------- | ------------------------------- |
| Code reduction vs naïve approach | > 50 %                          |
| Reused existing patterns         | > 70 %                          |
| New files per feature            | < 3                             |
| New DB tables                    | 0                               |
| Query complexity                 | No new indexes unless essential |
| Dev time vs estimate             | < 50 %                          |

---

## References

* [Anthropic: Extended Thinking](https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking)
* [FastAPI Docs](https://fastapi.tiangolo.com/)
* [SQLAlchemy 2.0 Tutorial](https://docs.sqlalchemy.org/en/20/tutorial/)
* [Celery Best Practices](https://docs.celeryq.dev/en/stable/)

---

*Remember: Every line of code is a liability. The best feature is one that needs **no new code**, just smarter use of what already exists.*
