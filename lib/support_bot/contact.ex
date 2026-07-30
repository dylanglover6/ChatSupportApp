defmodule SupportBot.Contact do
  @moduledoc """
  Delivers a real "email Dylan" message via the Resend HTTP API.

  This is deliberately separate from the DylanSupport ticket flow: tickets are a
  *simulated* portfolio demo, whereas this actually reaches Dylan's inbox. It uses the
  same `Req` HTTP client the AI provider uses — no SMTP/mailer library is added, keeping
  the `mix.exs` "no Swoosh/Bamboo" constraint intact.

  Configured entirely from env vars, read at call time (matching `AI.Client`):

    * `RESEND_API_KEY`    — required; when unset, delivery is skipped and `deliver/1`
                            returns `{:error, :not_configured}` so local/dev degrades
                            gracefully instead of crashing.
    * `CONTACT_TO_EMAIL`  — recipient (default `dylanglover6@gmail.com`).
    * `CONTACT_FROM_EMAIL` — verified Resend sender. Defaults to Resend's onboarding
                            sender, which delivers to the account owner's own address —
                            good enough to reach Dylan before a domain is verified.
  """
  require Logger

  @endpoint "https://api.resend.com/emails"
  @default_from "DylanBot <onboarding@resend.dev>"
  @default_to "dylanglover6@gmail.com"
  @max_name 200
  @max_message 5_000
  @email_re ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc "Whether real delivery is wired up (a Resend key is present)."
  def configured?, do: api_key() not in [nil, ""]

  @doc """
  Sends a contact message to Dylan.

  Expects a map with `:name`, `:email`, `:message` and an optional `:context` string
  (e.g. the page the visitor was on). Returns `{:ok, id}` on success, or
  `{:error, :not_configured | :invalid | :send_failed}`.
  """
  def deliver(params) do
    name =
      params |> Map.get(:name, "") |> to_string() |> String.trim() |> String.slice(0, @max_name)

    email = params |> Map.get(:email, "") |> to_string() |> String.trim()

    message =
      params
      |> Map.get(:message, "")
      |> to_string()
      |> String.trim()
      |> String.slice(0, @max_message)

    context = params |> Map.get(:context, "") |> to_string() |> String.trim()

    cond do
      not configured?() -> {:error, :not_configured}
      name == "" or message == "" or not valid_email?(email) -> {:error, :invalid}
      true -> post(name, email, message, context)
    end
  end

  defp post(name, email, message, context) do
    body = %{
      from: from(),
      to: [to()],
      reply_to: email,
      subject: "Portfolio contact from #{name}",
      text: text_body(name, email, message, context)
    }

    case Req.post(@endpoint,
           auth: {:bearer, api_key()},
           json: body,
           receive_timeout: 10_000,
           retry: false
         ) do
      {:ok, %{status: status, body: %{"id" => id}}} when status in 200..299 ->
        {:ok, id}

      {:ok, resp} ->
        Logger.error(
          "Resend send failed: status=#{inspect(resp.status)} body=#{inspect(resp.body)}"
        )

        {:error, :send_failed}

      {:error, reason} ->
        Logger.error("Resend request error: #{inspect(reason)}")
        {:error, :send_failed}
    end
  rescue
    e ->
      Logger.error("Resend exception: #{inspect(e)}")
      {:error, :send_failed}
  end

  defp text_body(name, email, message, context) do
    footer = if context == "", do: "", else: "\n\nContext: #{context}"

    """
    New message from your portfolio contact form.

    Name:  #{name}
    Email: #{email}

    #{message}#{footer}
    """
  end

  defp valid_email?(email), do: Regex.match?(@email_re, email)

  defp api_key, do: System.get_env("RESEND_API_KEY")
  defp from, do: env_or("CONTACT_FROM_EMAIL", @default_from)
  defp to, do: env_or("CONTACT_TO_EMAIL", @default_to)

  defp env_or(var, default) do
    case System.get_env(var) do
      value when value in [nil, ""] -> default
      value -> value
    end
  end
end
