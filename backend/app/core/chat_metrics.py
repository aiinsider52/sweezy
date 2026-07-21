from prometheus_client import Counter, Gauge


CHAT_CONVERSATIONS_CREATED = Counter(
    "sweezy_chat_conversations_created_total",
    "Marketplace conversations created",
    ("listing_type",),
)
CHAT_MESSAGES_SENT = Counter(
    "sweezy_chat_messages_sent_total",
    "Chat messages accepted by the API",
    ("listing_type", "kind"),
)
CHAT_DEALS_CLOSED = Counter(
    "sweezy_chat_deals_closed_total",
    "Marketplace deals closed from chat",
    ("listing_type",),
)
CHAT_REVIEWS_CREATED = Counter(
    "sweezy_chat_reviews_created_total",
    "Marketplace reviews created after a closed deal",
    ("listing_type",),
)
CHAT_SAFETY_ACTIONS = Counter(
    "sweezy_chat_safety_actions_total",
    "User safety actions in chat",
    ("action",),
)
CHAT_PUSH_DELIVERIES = Counter(
    "sweezy_chat_push_deliveries_total",
    "APNs delivery outcomes for chat notifications",
    ("outcome",),
)
CHAT_WEBSOCKET_CONNECTIONS = Gauge(
    "sweezy_chat_websocket_connections",
    "Currently connected chat WebSockets",
)
