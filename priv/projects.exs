[
  %{
    name: "SupportBot / DylanDocs",
    tagline:
      "You're looking at it: an AI support platform in Phoenix LiveView with RAG-style KB search. See DylanDocs for the case study.",
    stack: ["Elixir", "Phoenix LiveView", "Ecto/PostgreSQL", "Claude API"],
    slug: "project-support-platform",
    github: "https://github.com/dylanglover6/ChatSupportApp",
    live: nil,
    blurb:
      "This portfolio, DylanDocs, DylanBot, and DylanSupport are all one Phoenix/LiveView application. Local keyword search stands in for RAG, a rule-based engine classifies and routes tickets to mock agents, and Phoenix PubSub powers a live agent chat takeover across two browser windows.",
    highlights: [
      "Page-aware chat widget grounded in DylanDocs, with a deterministic fallback when the model is offline",
      "Rule-based triage: category, priority, support level, and expertise-based agent assignment",
      "Live agent takeover over Phoenix PubSub, no polling",
      "One \"Dark Arcade\" design system across the portfolio, docs, chat, and support desk"
    ],
    screenshots: [
      %{src: nil, caption: "Portfolio landing"},
      %{src: nil, caption: "DylanDocs + DylanBot"},
      %{src: nil, caption: "DylanSupport ticket desk"}
    ]
  },
  %{
    name: "Plot Twist",
    tagline:
      "A mobile-first MERN app for temporary, scratch-to-reveal invite links, with animated reveals, expiring share links, and calendar integration.",
    stack: ["React", "Node/Express", "MongoDB"],
    slug: "project-plot-twist",
    github: "https://github.com/dylanglover6/PlotTwist",
    live: nil,
    blurb:
      "Plot Twist turns an invitation into a moment: build a reveal page, choose when it unlocks, and send a single temporary link. The recipient sees a locked teaser and countdown, then scratches the screen to uncover the reveal before the link expires for good.",
    highlights: [
      "State you derive, never store: locked / revealed / expired from two timestamps and one pure function",
      "Scratch-to-reveal canvas over an image that blurs into focus",
      "A single Express service serves both the API and the built React bundle",
      "Add-to-calendar .ics on the fly; Unsplash search proxied to keep the key server-side"
    ],
    screenshots: [
      %{src: nil, caption: "Locked teaser + countdown"},
      %{src: nil, caption: "Scratch to reveal"},
      %{src: nil, caption: "Create an invite"}
    ]
  },
  %{
    name: "PromptCoach",
    tagline:
      "An AI coaching tool that scores, explains, and rewrites your prompts against a real rubric, with Learn and Practice modes.",
    stack: ["React", "Azure Functions", "Claude API"],
    slug: "project-promptcoach",
    github: nil,
    live: nil,
    blurb:
      "Most people never get feedback on why a prompt worked or didn't. PromptCoach closes that loop: paste a prompt and get a weighted score, a plain-language verdict, and a rewrite that fixes its specific gaps, plus Learn and Practice modes that turn prompt engineering into a skill you can measure.",
    highlights: [
      "Weighted 100-point rubric with the scoring math done in app code, not inside the model",
      "Tool-forced structured JSON from the Claude API, so the UI never parses fragile text",
      "Practice mode ends on a deliberately underspecified \"trap\" scenario",
      "One scoring engine reused across the rater and Practice grading"
    ],
    screenshots: [
      %{src: nil, caption: "Rate my prompt"},
      %{src: nil, caption: "Learn"},
      %{src: nil, caption: "Practice mode"}
    ]
  }
]
