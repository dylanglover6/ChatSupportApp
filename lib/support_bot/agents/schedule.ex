defmodule SupportBot.Agents.Schedule do
  def available?(agent, current_time \\ Time.utc_now()) do
    start_time = agent.shift_start
    end_time = agent.shift_end

    case Time.compare(start_time, end_time) do
      :lt ->
        Time.compare(current_time, start_time) != :lt and
          Time.compare(current_time, end_time) == :lt

      :gt ->
        Time.compare(current_time, start_time) != :lt or
          Time.compare(current_time, end_time) == :lt

      :eq ->
        true
    end
  end

  def shift_label(agent) do
    "#{format(agent.shift_start)} - #{format(agent.shift_end)}"
  end

  defp format(time), do: Calendar.strftime(time, "%I:%M %p")
end
