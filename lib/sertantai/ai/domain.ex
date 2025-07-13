defmodule Sertantai.AI do
  @moduledoc """
  AI Domain for Sertantai application.
  
  This domain manages all AI-powered functionality including:
  - Organization profile gap analysis
  - Intelligent question generation
  - Conversational session management
  - Natural language response processing
  """

  use Ash.Domain

  resources do
    resource Sertantai.AI.OrganizationAnalysis
    resource Sertantai.AI.QuestionGeneration
    resource Sertantai.AI.ConversationSession
    resource Sertantai.AI.ResponseProcessing
  end

  @doc """
  Returns the default OpenAI model configuration for AshAI.
  """
  def default_model do
    LangChain.ChatModels.ChatOpenAI.new!(%{
      model: "gpt-4o",
      temperature: 0.3,
      max_tokens: 2000
    })
  end

  @doc """
  Returns the OpenAI API key from environment variables.
  """
  def api_key do
    System.get_env("OPENAI_API_KEY") || 
      raise "OPENAI_API_KEY environment variable not set"
  end

  @doc """
  Validates that AI dependencies are properly configured.
  """
  def validate_config do
    case api_key() do
      nil -> {:error, "OpenAI API key not configured"}
      _key -> {:ok, "AI configuration valid"}
    end
  end
end