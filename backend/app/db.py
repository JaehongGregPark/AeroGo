from contextlib import contextmanager

import psycopg2
from psycopg2.extras import RealDictCursor

from .config import settings


@contextmanager
def get_connection():
    connection = psycopg2.connect(
        host=settings.postgres_host,
        port=settings.postgres_port,
        dbname=settings.postgres_database,
        user=settings.postgres_user,
        password=settings.postgres_password,
    )
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def dict_cursor(connection):
    """mysql-connector's `connection.cursor(dictionary=True)` equivalent for
    psycopg2 - returns rows as dicts keyed by column name instead of tuples.
    """
    return connection.cursor(cursor_factory=RealDictCursor)
