# frozen_string_literal: true

namespace :data do
  desc 'Seed Ben Demo Conference 2026 for live class demo of conference + event duplication feature'
  task ben_demo: :environment do
    short_title = 'bendemo25'

    existing = Conference.find_by(short_title: short_title)
    if existing
      puts "Destroying existing '#{short_title}' conference to regenerate..."
      Role.where(resource: existing).delete_all
      existing.destroy!
    end

    puts 'Creating Ben Demo Conference 2026...'

    # --- Organization ---
    org = Organization.first_or_create!(name: 'Demo Organization')
    puts "Using organization: #{org.name}"

    # --- Conference ---
    conference = Conference.create!(
      title:       'Ben Demo Conference 2026',
      short_title: short_title,
      organization: org,
      start_date:  Date.new(2026, 10, 14),
      end_date:    Date.new(2026, 10, 16),
      start_hour:  9,
      end_hour:    18,
      timezone:    'America/Los_Angeles',
      description: 'Ben Demo Conference is a three-day gathering for software engineers, ' \
                   'architects, and technical leaders focused on modern web development, ' \
                   'distributed systems, and applied machine learning. ' \
                   'Attendees leave with practical techniques they can apply the following Monday.'
    )
    puts "Created conference: #{conference.title} (id=#{conference.id})"

    # --- Venue + Rooms ---
    venue = Venue.create!(
      conference: conference,
      name:       'Berkeley Convention Center',
      street:     '2026 Center St',
      city:       'Berkeley',
      country:    'US',
      postalcode: '94704'
    )
    puts "Created venue: #{venue.name}"

    room_data = [
      { name: 'Main Auditorium',   size: 800, order: 1 },
      { name: 'Hall A',            size: 300, order: 2 },
      { name: 'Hall B',            size: 300, order: 3 },
      { name: 'Workshop Room 1',   size: 80,  order: 4 },
      { name: 'Workshop Room 2',   size: 80,  order: 5 },
      { name: 'Networking Lounge', size: 200, order: 6 }
    ]

    rooms = room_data.map do |r|
      room = venue.rooms.create!(name: r[:name], size: r[:size], order: r[:order])
      puts "  Created room: #{room.name}"
      room
    end

    main_hall, hall_a, hall_b, workshop1, workshop2, _lounge = rooms

    # --- Program ---
    program = conference.program
    puts "Program id=#{program.id}"

    # --- CFP ---
    cfp = Cfp.create!(
      program:    program,
      cfp_type:   'events',
      start_date: Date.new(2026, 6, 1),
      end_date:   Date.new(2026, 8, 15),
      description: 'We welcome proposals for talks (30 min) and workshops (90 min) on ' \
                   'frontend engineering, backend systems, AI/ML in production, and DevOps.'
    )
    puts "Created CFP (events): #{cfp.start_date} - #{cfp.end_date}"

    # --- Event Types ---
    talk_type = program.event_types.create!(
      title:  'Talk',
      length: 30,
      color:  '#1F77B4',
      minimum_abstract_length: 100,
      maximum_abstract_length: 1000
    )
    workshop_type = program.event_types.create!(
      title:  'Workshop',
      length: 90,
      color:  '#FF7F0E',
      minimum_abstract_length: 100,
      maximum_abstract_length: 1000
    )
    puts "Created event types: Talk, Workshop"

    # --- Tracks ---
    # Colors must be unique per program. State is set to 'confirmed' via update_column
    # after create so the valid_track validation on Event accepts them.
    # Using AASM transitions would require a submitter for the confirm callback,
    # which does not apply to organizer-created tracks.
    track_data = [
      { name: 'Frontend Engineering',     short_name: 'frontend', color: '#1F77B4' },
      { name: 'Backend Systems',          short_name: 'backend',  color: '#2CA02C' },
      { name: 'AI & Machine Learning',    short_name: 'aiml',     color: '#9467BD' },
      { name: 'DevOps & Infrastructure',  short_name: 'devops',   color: '#D62728' }
    ]

    tracks = track_data.map do |t|
      track = program.tracks.create!(
        name:       t[:name],
        short_name: t[:short_name],
        color:      t[:color],
        cfp_active: false,
        state:      'new'
      )
      track.update_column(:state, 'confirmed')
      puts "  Created track: #{track.name} (confirmed)"
      track
    end

    fe_track, be_track, ai_track, ops_track = tracks

    # --- Speakers (users) ---
    speaker_data = [
      { name: 'Priya Mehta',       email: 'priya.mehta@bendemo25.example.com',    username: 'priyamehta_bd25' },
      { name: 'Carlos Rivera',     email: 'carlos.rivera@bendemo25.example.com',  username: 'crivera_bd25' },
      { name: 'Aisha Okonkwo',     email: 'aisha.okonkwo@bendemo25.example.com',  username: 'aokonkwo_bd25' },
      { name: 'James Whitfield',   email: 'james.whitfield@bendemo25.example.com',username: 'jwhitfield_bd25' },
      { name: 'Mei-Ling Zhang',    email: 'meiling.zhang@bendemo25.example.com',  username: 'mlzhang_bd25' },
      { name: 'Dmitri Volkov',     email: 'dmitri.volkov@bendemo25.example.com',  username: 'dvolkov_bd25' },
      { name: 'Sara Lindqvist',    email: 'sara.lindqvist@bendemo25.example.com', username: 'slindqvist_bd25' },
      { name: 'Kofi Asante',       email: 'kofi.asante@bendemo25.example.com',    username: 'kasante_bd25' }
    ]

    speakers = speaker_data.map do |s|
      user = User.find_or_initialize_by(email: s[:email])
      if user.new_record?
        user.name     = s[:name]
        user.username = s[:username]
        user.password = SecureRandom.hex(16)
        user.skip_confirmation!
        user.save!
      end
      puts "  Speaker: #{user.name}"
      user
    end

    priya, carlos, aisha, james, meiling, dmitri, sara, kofi = speakers

    # --- Events ---
    # Helper: create an event with speaker and schedule in one shot.
    # The before_end_of_conference validation runs on :create and checks
    # Date.today > conference.end_date. Conference end_date is 2026-10-16,
    # so any create before that date will pass.
    # The valid_track validation requires track.confirmed? -- ensured above.
    # Abstracts must be >= 100 words per the event type minimum_abstract_length.
    def make_event(program:, title:, subtitle:, abstract:, event_type:, track:, state: 'confirmed')
      program.events.create!(
        title:      title,
        subtitle:   subtitle,
        abstract:   abstract,
        event_type: event_type,
        track:      track,
        state:      state,
        language:   'English'
      )
    end

    events_list = []

    events_list << make_event(
      program:    program,
      title:      'React Server Components in Production: Lessons from Six Months',
      subtitle:   'Moving beyond the hype to real-world performance wins',
      abstract:   "React Server Components promised to simplify data-fetching and shrink client bundles. " \
                  "After six months running RSC in production at scale, we have real numbers to share. " \
                  "This talk walks through our migration from a traditional single-page application, the " \
                  "gotchas we hit with streaming hydration, and the performance improvements we measured " \
                  "across three different page types. We reduced initial JavaScript payload by 38 percent " \
                  "and improved Largest Contentful Paint by more than 700 milliseconds on median hardware.\n\n" \
                  "We will cover our deployment architecture, how we structured the client and server " \
                  "boundary, the caching strategy that surprised us, and the tooling we built to catch " \
                  "accidental client-side data leaks before they reached production. Attendees will leave " \
                  "with a concrete migration checklist and the war stories that informed it.",
      event_type: talk_type,
      track:      fe_track
    )

    events_list << make_event(
      program:    program,
      title:      'CSS Container Queries: The Composable Layout Revolution',
      subtitle:   'Writing components that respond to their context, not the viewport',
      abstract:   "For years we wrote breakpoints against the viewport even though components live inside " \
                  "containers of all shapes and sizes. Container queries finally let us write truly portable " \
                  "UI. This session dives deep into @container, inline-size units, style queries, and the " \
                  "new :has() pseudo-class that unlocks parent-aware styling without JavaScript.\n\n" \
                  "We will refactor a real production design system live on stage, replacing a tangle of " \
                  "media-query overrides with clean container-aware components. Along the way we will discuss " \
                  "browser support timelines, progressive enhancement strategies for older browsers, and the " \
                  "performance characteristics of container queries compared to resize observer approaches. " \
                  "Expect plenty of before-and-after comparisons and a take-home demo repository you can " \
                  "fork and use immediately.",
      event_type: talk_type,
      track:      fe_track
    )

    events_list << make_event(
      program:    program,
      title:      'State Machines for UI: Eliminating Impossible States',
      subtitle:   'Using XState and statechart theory to tame complex async flows',
      abstract:   "Async UIs accumulate impossible states faster than any other part of a frontend. " \
                  "Loading and error simultaneously. Data present but stale but also refreshing. A button " \
                  "that is disabled for three different reasons at once. This talk introduces statechart-driven " \
                  "UI as a discipline, not just a library choice. The insight is simple: if you cannot draw " \
                  "the state machine, you do not understand the feature yet.\n\n" \
                  "We will model three real-world components in XState: a multi-step checkout form, an " \
                  "optimistic list with undo, and a real-time collaboration indicator. Then we will show how " \
                  "the model drives unit tests, accessibility attributes, and Storybook stories almost " \
                  "automatically. No XState experience required; statechart intuition is all you need.",
      event_type: talk_type,
      track:      fe_track
    )

    events_list << make_event(
      program:    program,
      title:      'Building Resilient APIs with Rate Limiting and Backpressure',
      subtitle:   'Protecting your services without frustrating your callers',
      abstract:   "Rate limiting is easy to add and easy to get wrong. Naive fixed-window counters create " \
                  "thundering herd problems at window resets. Leaky buckets under-protect during legitimate " \
                  "traffic bursts. This talk surveys the algorithmic options available today: token bucket, " \
                  "sliding log, and GCRA, explaining when each is the right choice and what the failure modes " \
                  "look like under load.\n\n" \
                  "We will then look at the caller side of the problem: how services should handle 429 " \
                  "responses, implement exponential backoff with jitter, and propagate backpressure through " \
                  "async queues without cascading failures. Real Nginx, Redis, and Sidekiq configurations are " \
                  "included. Attendees will leave with a decision framework and copy-paste-ready config " \
                  "snippets for the most common stack combinations.",
      event_type: talk_type,
      track:      be_track
    )

    events_list << make_event(
      program:    program,
      title:      'PostgreSQL Query Planner Deep Dive',
      subtitle:   'Understanding EXPLAIN ANALYZE output to stop guessing about slow queries',
      abstract:   "Most engineers treat the query planner as a black box and sprinkle indexes hopefully. " \
                  "This session demystifies EXPLAIN ANALYZE output line by line: what sequential scan versus " \
                  "index scan actually means, when a nested loop beats a hash join, and why table statistics " \
                  "matter more than indexes in many cases.\n\n" \
                  "We will optimize a curated set of pathological real-world queries live on stage, covering " \
                  "partial indexes, expression indexes, covering indexes, and the pg_stat_statements view that " \
                  "shows you which queries hurt the most. You will leave knowing exactly which knob to turn " \
                  "the next time a query is slow, and with enough mental model to read a query plan without " \
                  "reaching for a tutorial.",
      event_type: talk_type,
      track:      be_track
    )

    events_list << make_event(
      program:    program,
      title:      'Event Sourcing Without the Ceremony',
      subtitle:   'Capturing intent and history in a Rails app without an event-sourcing framework',
      abstract:   "Event sourcing carries a reputation for complexity: CQRS projections, eventual consistency, " \
                  "saga orchestrators, and a complete rethink of your data model. But the core idea behind " \
                  "event sourcing is simpler than its reputation: record what happened, not just the final " \
                  "state. That idea can be adopted incrementally in a plain Rails application without a " \
                  "framework and without a big-bang rewrite.\n\n" \
                  "This talk presents a pragmatic subset: append-only domain events stored alongside existing " \
                  "ActiveRecord models, a lightweight projection pattern for building read models, and a " \
                  "migration strategy that keeps the existing system running the whole time. Three production " \
                  "case studies show the tradeoffs you will actually face, not the idealized version from " \
                  "conference talks.",
      event_type: talk_type,
      track:      be_track
    )

    events_list << make_event(
      program:    program,
      title:      'gRPC at the Edge: Streaming APIs for Real-Time Collaboration',
      subtitle:   'Replacing polling with bidirectional streams in a multi-tenant SaaS product',
      abstract:   "Our collaborative editing feature started with polling every two seconds. It ended with " \
                  "gRPC bidirectional streaming, a fanout service in Go, and latency measured in single-digit " \
                  "milliseconds instead of seconds. This talk narrates that journey honestly, including the " \
                  "dead ends we hit and the weeks we lost to load-balancer configuration.\n\n" \
                  "Topics include Protobuf schema design for change feeds, the challenge of load-balancing " \
                  "long-lived streams behind a standard application load balancer, and the surprising " \
                  "operational differences between unary and streaming RPCs in production. Envoy proxy " \
                  "configuration snippets and a comparison of client-side reconnect strategies are included. " \
                  "Attendees building collaborative or real-time features will leave with a realistic picture " \
                  "of what this migration actually costs.",
      event_type: talk_type,
      track:      be_track
    )

    events_list << make_event(
      program:    program,
      title:      'Practical RAG: Production Lessons from a Year of LLM Apps',
      subtitle:   'What retrieval-augmented generation actually looks like at scale',
      abstract:   "Retrieval-Augmented Generation is the first architectural pattern most teams reach for " \
                  "when adding LLMs to an existing product. After a year of running RAG in production across " \
                  "three different domains: legal documents, customer support transcripts, and internal " \
                  "knowledge bases, we have accumulated hard-won lessons about chunking strategies, embedding " \
                  "model selection, reranking, and evaluation.\n\n" \
                  "This talk shares what worked, what did not, and the evaluations we wish we had written on " \
                  "day one. We will cover infrastructure choices including pgvector versus Pinecone versus " \
                  "Weaviate, explain when those tradeoffs actually matter versus when they are premature " \
                  "optimization, and walk through the failure modes that only appear at scale. Concrete " \
                  "benchmarks and a reference architecture diagram are included.",
      event_type: talk_type,
      track:      ai_track
    )

    events_list << make_event(
      program:    program,
      title:      'Fine-Tuning vs Prompting: When to Pay the Training Tax',
      subtitle:   'A decision framework for teams with limited ML resources',
      abstract:   "Every team running an LLM-powered feature faces the same question eventually: should we " \
                  "fine-tune, or can clever prompting get us there? The honest answer depends on data volume, " \
                  "latency requirements, cost targets, and how stable the task definition is. This talk lays " \
                  "out a structured decision framework built from real production decisions.\n\n" \
                  "We walk through three cases where we made the call in different directions: one where " \
                  "prompting was sufficient and fine-tuning would have been waste, one where fine-tuning " \
                  "unlocked a 40 percent quality improvement that no prompt engineering could match, and one " \
                  "where we started with prompting and migrated later. We cover LoRA adapters, DPO for " \
                  "preference alignment, and the evaluation harness that made each comparison statistically " \
                  "defensible.",
      event_type: talk_type,
      track:      ai_track
    )

    events_list << make_event(
      program:    program,
      title:      'Responsible AI Deployment: Guardrails That Actually Work',
      subtitle:   'Moving beyond content filters to robust, testable safety pipelines',
      abstract:   "Bolting a content filter onto an LLM API call is not a safety strategy. It is a " \
                  "checkbox. This talk presents a layered approach to responsible AI deployment that treats " \
                  "safety as an engineering discipline: input validation, output schema enforcement, semantic " \
                  "guardrails, confidence thresholds, and human-in-the-loop escalation paths with measurable " \
                  "coverage.\n\n" \
                  "We examine each layer through the lens of testability. How do you write a regression test " \
                  "for a guardrail? How do you know your safety pipeline has not regressed after a model " \
                  "upgrade? We share the incident post-mortems that drove each addition to our pipeline and " \
                  "the metrics we now track in production. Code examples are in Python and designed to be " \
                  "tooling-agnostic so you can apply them regardless of which LLM provider you use.",
      event_type: talk_type,
      track:      ai_track
    )

    events_list << make_event(
      program:    program,
      title:      'Kubernetes Cost Optimization: From $40k to $18k per Month',
      subtitle:   'Rightsizing, spot instances, and autoscaling without oncall nightmares',
      abstract:   "Cloud bills have a way of sneaking up on engineering teams, and Kubernetes makes it " \
                  "surprisingly easy to over-provision at every layer. We reduced our monthly Kubernetes " \
                  "spend by 55 percent over six months without a single production incident caused by the " \
                  "cost work. This talk explains exactly how we did it and what we would do differently.\n\n" \
                  "We cover VPA and KEDA for rightsizing and event-driven autoscaling, our phased strategy " \
                  "for migrating stateless workloads to spot and preemptible instances with graceful drain " \
                  "handling, and the observability setup using Kubecost and custom Grafana dashboards that " \
                  "made every decision visible to both engineering and finance. The session ends with a " \
                  "prioritized checklist of optimizations ordered by typical impact versus implementation " \
                  "effort.",
      event_type: talk_type,
      track:      ops_track
    )

    events_list << make_event(
      program:    program,
      title:      'GitOps in Practice: ArgoCD Patterns for Multi-Tenant Clusters',
      subtitle:   'Structuring policy, tenancy, and continuous delivery at scale',
      abstract:   "GitOps promises a single source of truth for cluster state, but the path from one " \
                  "cluster and one team to many clusters and many teams reveals surprising complexity. " \
                  "This talk shares the ArgoCD patterns we have settled on after two years of operating " \
                  "a multi-tenant Kubernetes platform serving more than thirty product teams.\n\n" \
                  "Topics include ApplicationSet generators for zero-touch tenant onboarding, the tradeoffs " \
                  "between the app-of-apps pattern and flat repository layouts, RBAC design that does not " \
                  "require a deep background in OPA to understand or maintain, and our drift-detection and " \
                  "remediation runbook. We also discuss the cultural changes that made GitOps stick after " \
                  "previous attempts with Helm failed to gain adoption.",
      event_type: talk_type,
      track:      ops_track
    )

    events_list << make_event(
      program:    program,
      title:      'OpenTelemetry: Distributed Tracing Across a Polyglot Stack',
      subtitle:   'Instrumenting Ruby, Go, and Python services with a single observability backend',
      abstract:   "Distributed tracing sounds straightforward until you have services in three languages, " \
                  "two message brokers, and a legacy monolith that predates modern APM tooling. This talk " \
                  "walks through our OpenTelemetry adoption across a real heterogeneous system: auto- " \
                  "instrumentation where it works, manual spans where it does not, and the collector " \
                  "pipeline that fans out to both Jaeger and our commercial APM vendor.\n\n" \
                  "We pay special attention to Rails and Sidekiq instrumentation quirks, baggage propagation " \
                  "across async queue boundaries, and the Grafana dashboards we built to surface P99 latency " \
                  "regressions before customers notice them. Attendees will leave with an instrumentation " \
                  "checklist and an understanding of where OpenTelemetry still requires manual effort " \
                  "despite the promise of automatic instrumentation.",
      event_type: talk_type,
      track:      ops_track
    )

    # Two workshops
    events_list << make_event(
      program:    program,
      title:      'Hands-On: Building Your First RAG Pipeline',
      subtitle:   'From a pile of PDFs to a working Q&A system in 90 minutes',
      abstract:   "In this hands-on workshop you will build a complete retrieval-augmented generation " \
                  "pipeline from scratch. Starting with raw PDF documents, you will chunk and embed them " \
                  "into a pgvector database, wire up a retrieval step that selects relevant passages, and " \
                  "query an LLM with grounded context instead of relying on training data alone.\n\n" \
                  "Prerequisites: Python 3.11 or newer, a laptop, and an OpenAI API key (free tier is " \
                  "sufficient). All starter code is provided and we will walk through it together. By the " \
                  "end of the session you will have a working system you understand end-to-end, hands-on " \
                  "experience debugging retrieval quality issues, and the mental model needed to adapt the " \
                  "pipeline to your own data sources. No prior LLM experience is required.",
      event_type: workshop_type,
      track:      ai_track
    )

    events_list << make_event(
      program:    program,
      title:      'Workshop: Zero-Downtime Deployments with Kamal and Health Checks',
      subtitle:   'Configure rolling deploys, readiness probes, and automated rollbacks',
      abstract:   "Kamal makes Docker-based zero-downtime deploys accessible to teams that do not have a " \
                  "Kubernetes budget or want the operational simplicity of deploying directly to VMs. In " \
                  "this workshop we will deploy a sample Rails application to a pair of cloud VMs, configure " \
                  "Traefik health checks that prevent bad releases from going live, implement database " \
                  "migration strategies that avoid table locks, and trigger an automated rollback.\n\n" \
                  "You will work in pairs on pre-provisioned VMs. Bring a laptop with Docker installed. " \
                  "We will cover the Kamal configuration file in detail, discuss secrets management " \
                  "options, and walk through the deploy lifecycle from image build to traffic cutover. " \
                  "The session ends with a war-game exercise where attendees attempt to break their " \
                  "partner's deploy pipeline while the other defends it.",
      event_type: workshop_type,
      track:      ops_track
    )

    events_list << make_event(
      program:    program,
      title:      'Accessibility Testing as Part of CI: No More Last-Minute Audits',
      subtitle:   'Integrating axe-core, VoiceOver testing, and keyboard navigation checks into your pipeline',
      abstract:   "Accessibility is consistently pushed to the end of projects and then rushed or cut " \
                  "entirely. The fix is not more awareness training or better intentions: it is automation " \
                  "that catches the majority of issues before code review so that humans can focus on the " \
                  "problems that require judgment.\n\n" \
                  "This talk presents a layered accessibility testing strategy built from tools available " \
                  "today in any JavaScript project. We cover axe-core integrated into Jest and Playwright " \
                  "tests, snapshot testing for ARIA trees that catches regressions in screen reader " \
                  "experience, keyboard navigation test helpers that simulate tab order without a real " \
                  "browser, and the color-contrast linter that catches design-token regressions at the " \
                  "source. Every technique shown has a corresponding CI configuration you can copy and " \
                  "adapt to your own pipeline today.",
      event_type: talk_type,
      track:      fe_track
    )

    puts "Created #{events_list.size} events"

    # --- Assign speakers to events ---
    speaker_assignments = [
      [events_list[0],  priya,   'speaker'],
      [events_list[1],  carlos,  'speaker'],
      [events_list[2],  aisha,   'speaker'],
      [events_list[3],  james,   'speaker'],
      [events_list[4],  meiling, 'speaker'],
      [events_list[5],  dmitri,  'speaker'],
      [events_list[6],  james,   'speaker'],
      [events_list[6],  sara,    'speaker'],  # co-speaker
      [events_list[7],  aisha,   'speaker'],
      [events_list[8],  kofi,    'speaker'],
      [events_list[9],  meiling, 'speaker'],
      [events_list[10], dmitri,  'speaker'],
      [events_list[11], carlos,  'speaker'],
      [events_list[12], sara,    'speaker'],
      [events_list[13], priya,   'speaker'],
      [events_list[14], kofi,    'speaker'],
      [events_list[15], james,   'speaker'],
      [events_list[15], aisha,   'speaker']   # co-speaker
    ]

    speaker_assignments.each do |ev, user, role|
      EventUser.create!(event: ev, user: user, event_role: role)
    end
    puts "Assigned speakers to events"

    # --- Schedule ---
    # Create a schedule and assign it as selected
    schedule = Schedule.create!(program: program)
    program.update_column(:selected_schedule_id, schedule.id)
    puts "Created schedule id=#{schedule.id}, set as selected"

    # Slot each event into a room + time. Three days, no double-booking.
    # Day 0 = Oct 14, Day 1 = Oct 15, Day 2 = Oct 16
    # Format: [event_index, day_offset, start_hour, room]
    slot_assignments = [
      # Day 1 - Oct 14
      [0,  0, 9,  main_hall],    # React Server Components
      [3,  0, 9,  hall_a],       # Resilient APIs
      [10, 0, 9,  hall_b],       # K8s Cost Optimization
      [1,  0, 10, main_hall],    # CSS Container Queries
      [4,  0, 10, hall_a],       # Postgres Query Planner
      [11, 0, 10, hall_b],       # GitOps ArgoCD
      [13, 0, 11, workshop1],    # RAG Workshop (90 min)
      [2,  0, 13, main_hall],    # State Machines for UI
      [5,  0, 13, hall_a],       # Event Sourcing
      [12, 0, 13, hall_b],       # OpenTelemetry
      [15, 0, 14, workshop2],    # Accessibility in CI
      # Day 2 - Oct 15
      [7,  1, 9,  main_hall],    # Practical RAG
      [6,  1, 9,  hall_a],       # gRPC streaming
      [8,  1, 10, main_hall],    # Fine-Tuning vs Prompting
      [9,  1, 11, main_hall],    # Responsible AI
      [14, 1, 11, workshop1],    # Kamal Workshop (90 min)
    ]

    base_date = conference.start_date

    slot_assignments.each do |ev_idx, day_offset, hour, room|
      event = events_list[ev_idx]
      start_time = (base_date + day_offset.days).to_time.utc.change(hour: hour)
      EventSchedule.create!(
        event:    event,
        schedule: schedule,
        room:     room,
        start_time: start_time
      )
    end
    puts "Scheduled #{slot_assignments.size} events across 2 days"

    # --- Tickets ---
    # Conference#after_create creates one free registration ticket automatically.
    # Add paid tiers on top.
    conference.tickets.create!(
      title:              'Early Bird',
      description:        'Discounted rate for attendees who register before August 1, 2026.',
      price_cents:        14_900,
      price_currency:     'USD',
      registration_ticket: false,
      visible:            true
    )
    conference.tickets.create!(
      title:              'Regular',
      description:        'Standard conference admission including all sessions and meals.',
      price_cents:        29_900,
      price_currency:     'USD',
      registration_ticket: false,
      visible:            true
    )
    conference.tickets.create!(
      title:              'Student',
      description:        'Reduced-price ticket for full-time students. Student ID required at check-in.',
      price_cents:         7_500,
      price_currency:     'USD',
      registration_ticket: false,
      visible:            true
    )
    puts "Created 3 paid ticket tiers (Early Bird $149, Regular $299, Student $75)"
    puts "  (plus the automatic free registration ticket)"

    # --- Registration Period ---
    RegistrationPeriod.create!(
      conference: conference,
      start_date: Date.new(2026, 7, 1),
      end_date:   Date.new(2026, 10, 16)
    )
    puts "Created registration period: 2026-07-01 to 2026-10-16"

    # --- Attendee Registrations ---
    attendee_data = [
      { name: 'Alex Morgan',      email: 'alex.morgan@bendemo25.example.com',    username: 'amorgan_bd25' },
      { name: 'Fatima Al-Hassan', email: 'fatima.alhassan@bendemo25.example.com',username: 'falhassan_bd25' },
      { name: 'Tom Nakamura',     email: 'tom.nakamura@bendemo25.example.com',   username: 'tnakamura_bd25' },
      { name: 'Elena Petrov',     email: 'elena.petrov@bendemo25.example.com',   username: 'epetrov_bd25' },
      { name: 'Marcus Webb',      email: 'marcus.webb@bendemo25.example.com',    username: 'mwebb_bd25' },
      { name: 'Nadia Osei',       email: 'nadia.osei@bendemo25.example.com',     username: 'nosei_bd25' },
      { name: 'Ryan Castellano',  email: 'ryan.castellano@bendemo25.example.com',username: 'rcastellano_bd25' }
    ]

    attendee_data.each do |a|
      user = User.find_or_initialize_by(email: a[:email])
      if user.new_record?
        user.name     = a[:name]
        user.username = a[:username]
        user.password = SecureRandom.hex(16)
        user.skip_confirmation!
        user.save!
      end
      Registration.create!(conference: conference, user: user)
      puts "  Registered attendee: #{user.name}"
    end

    # --- Splashpage ---
    Splashpage.create!(
      conference:           conference,
      public:               true,
      include_tracks:       true,
      include_program:      true,
      include_venue:        true,
      include_tickets:      true,
      include_registrations: true,
      include_cfp:          false,
      include_sponsors:     false,
      include_lodgings:     false,
      include_social_media: false,
      include_booths:       false
    )
    puts "Created splashpage (public)"

    puts ''
    puts '=== Ben Demo Conference 2026 seeded successfully ==='
    puts "  Conference id: #{conference.id}"
    puts "  URL slug:      #{short_title}"
    puts "  Tracks:        #{tracks.size}"
    puts "  Rooms:         #{rooms.size}"
    puts "  Events:        #{events_list.size}"
    puts "  Scheduled:     #{slot_assignments.size}"
    puts "  Tickets:       #{conference.tickets.count} (including free registration ticket)"
    puts "  Registrations: #{conference.registrations.count}"
    puts ''
    puts "Run with: rake data:ben_demo"
  end
end
