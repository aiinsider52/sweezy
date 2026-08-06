from backend.app.routers.ai import (
    CVEducation,
    CVExperience,
    CVImproveRequest,
    CVLanguage,
    CVPersonal,
    CVResumePayload,
    _fallback_improve,
    _fallback_translation,
)


def _resume() -> CVResumePayload:
    return CVResumePayload(
        personal=CVPersonal(
            fullName="Olena Kovalenko",
            title="Менеджер проєктів",
            email="olena@example.com",
            phone="+41 79 123 45 67",
            location="Zürich",
            summary="Керувала 4 проєктами з бюджетом 50 000 CHF.",
        ),
        experience=[
            CVExperience(
                id="experience-1",
                role="Менеджер",
                company="Example AG",
                period="2022–2025",
                location="Zürich",
                achievements="Керувала 4 проєктами\nСкоротила витрати на 12%",
            )
        ],
        education=[
            CVEducation(
                id="education-1",
                school="Київський університет",
                degree="Магістр економіки",
                period="2016–2021",
                details="Диплом з відзнакою",
            )
        ],
        languages=[CVLanguage(id="language-1", name="Українська", level="Рідна")],
        skills=["Управління проєктами", "Excel"],
        hobbies=["Біг"],
    )


def test_improve_fallback_preserves_source_facts_without_boilerplate():
    resume = _resume()
    request = CVImproveRequest(**resume.model_dump(), target="experience:experience-1")

    result = _fallback_improve(request)

    assert result == "• Керувала 4 проєктами\n• Скоротила витрати на 12%"
    assert "стейкхолдерами" not in result


def test_translation_fallback_preserves_complete_structured_cv():
    resume = _resume()

    result = _fallback_translation(resume)

    assert result.generated_by_ai is False
    assert result.personal == resume.personal
    assert result.experience == resume.experience
    assert result.education == resume.education
    assert result.languages == resume.languages
    assert result.skills == resume.skills
    assert result.hobbies == resume.hobbies
