"""
Vector Store update pipeline triggered by confirmed oracle events.

Example usage:
    from FakeEmbedder import embed  # replace with real BGE-Large embedder
    from pymongo import MongoClient

    client = MongoClient("mongodb+srv://...")
    collection = client["continuum"]["policy_chunks"]

    scraper = DisruptionScraper()  # implements fetch_disruption_summaries(zone_id, event_type)
    updater = VectorStoreUpdater(scraper=scraper, embedder=embed, mongo_collection=collection)

    consumer = KafkaOracleTriggerConsumer(
        kafka_bootstrap_servers="localhost:9092",
        topic="oracle_trigger",
        updater=updater,
    )
    consumer.start()
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Callable, Protocol

from .models import PolicyDocument

logger = logging.getLogger(__name__)


class Scraper(Protocol):
    def fetch_disruption_summaries(self, zone_id: str, event_type: str) -> list[str]:
        ...


class VectorStoreUpdater:
    """
    Handles the oracle-triggered vector store update pipeline:
      scrape → chunk → embed → upsert to MongoDB Atlas.

    All external dependencies are injected for testability.
    """

    def __init__(
        self,
        scraper: Scraper,
        embedder: Callable[[str], list[float]],
        mongo_collection: Any,
    ) -> None:
        self._scraper = scraper
        self._embedder = embedder
        self._collection = mongo_collection

    def handle_oracle_trigger(self, event: dict) -> int:
        """
        Process a confirmed oracle trigger event.

        Args:
            event: dict with keys zone_id, event_type, event_id

        Returns:
            Number of chunks upserted to the vector store.
        """
        zone_id: str = event["zone_id"]
        event_type: str = event["event_type"]
        event_id: str = event["event_id"]

        summaries: list[str] = self._scraper.fetch_disruption_summaries(zone_id, event_type)

        chunks: list[str] = []
        for summary in summaries:
            paragraphs = [p.strip() for p in summary.split("\n\n") if p.strip()]
            if paragraphs:
                chunks.extend(paragraphs)
            else:
                chunks.append(summary)

        upserted = 0
        now = datetime.now(tz=timezone.utc)

        for chunk in chunks:
            chunk_id = f"disruption_{event_id}_{uuid.uuid4().hex[:8]}"
            embedding = self._embedder(chunk)

            doc = PolicyDocument(
                chunk_id=chunk_id,
                source_type="disruption_event",
                content=chunk,
                embedding=embedding,
                metadata={
                    "zone_id": zone_id,
                    "event_type": event_type,
                    "event_id": event_id,
                },
                created_at=now,
                updated_at=now,
            )

            self._collection.replace_one(
                {"chunk_id": doc.chunk_id},
                doc.to_dict(),
                upsert=True,
            )
            upserted += 1

        logger.info(
            "oracle_trigger processed: event_id=%s zone_id=%s event_type=%s chunks_upserted=%d",
            event_id,
            zone_id,
            event_type,
            upserted,
        )
        return upserted


class KafkaOracleTriggerConsumer:
    """
    Kafka consumer that listens on the oracle_trigger topic and delegates
    each message to VectorStoreUpdater.handle_oracle_trigger.

    All external dependencies (kafka, updater) are injected for testability.
    """

    def __init__(
        self,
        kafka_bootstrap_servers: str,
        topic: str,
        updater: VectorStoreUpdater,
    ) -> None:
        self._bootstrap_servers = kafka_bootstrap_servers
        self._topic = topic
        self._updater = updater

    def start(self) -> None:
        """Create a KafkaConsumer and process messages in a blocking loop."""
        import kafka  # imported lazily so the class is importable without kafka installed

        consumer = kafka.KafkaConsumer(
            self._topic,
            bootstrap_servers=self._bootstrap_servers,
            value_deserializer=lambda v: v,  # raw bytes; parsing done in _parse_event
            auto_offset_reset="earliest",
            enable_auto_commit=True,
        )

        logger.info("KafkaOracleTriggerConsumer started on topic=%s", self._topic)

        for message in consumer:
            try:
                event = self._parse_event(message)
                count = self._updater.handle_oracle_trigger(event)
                logger.debug("Upserted %d chunks for message offset=%d", count, message.offset)
            except Exception:
                logger.exception(
                    "Failed to process oracle_trigger message offset=%d", message.offset
                )

    def _parse_event(self, message: Any) -> dict:
        """JSON-parse the raw Kafka message value into an event dict."""
        return json.loads(message.value)
