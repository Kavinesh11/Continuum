import os


def make_gemini_llm():
    from crewai import LLM  # noqa: PLC0415
    return LLM(
        model="gemini/gemini-2.5-pro",
        api_key=os.environ["GEMINI_API_KEY"],
    )


def make_gemini_flash_llm():
    from crewai import LLM  # noqa: PLC0415
    return LLM(
        model="gemini/gemini-2.0-flash",
        api_key=os.environ["GEMINI_API_KEY"],
    )
