from prometheus_client import Counter

EMAIL_DELIVERY_ATTEMPTS = Counter(
    "sweezy_email_delivery_attempts_total",
    "Transactional email requests sent to the provider, including retries",
    ("email_type",),
)

EMAIL_DELIVERY_OUTCOMES = Counter(
    "sweezy_email_delivery_outcomes_total",
    "Final transactional email delivery outcomes",
    ("email_type", "outcome"),
)
