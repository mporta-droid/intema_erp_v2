from app.db.session import SessionLocal
from app.services.seed import seed_phase1


def main() -> None:
    db = SessionLocal()
    try:
        seed_phase1(db)
        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    main()