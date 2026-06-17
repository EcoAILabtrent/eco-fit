import json
import tempfile
import unittest
from pathlib import Path

from tooling.food_review_server import FoodStore, ValidationError


class FoodStoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.data_path = Path(self.temp_dir.name) / "foods.json"
        self.data_path.write_text(
            json.dumps(
                [
                    {
                        "slug": "olma",
                        "name_uz_lat": "Olma",
                        "name_uz_kril": "Олма",
                        "name_ru": "Яблоко",
                        "name_en": "Apple",
                        "category": "Mevalar",
                    }
                ],
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        self.store = FoodStore(self.data_path, rebuild_database=False)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_lists_all_language_names(self) -> None:
        item = self.store.list_foods()[0]
        self.assertEqual(item["names"]["ru"], "Яблоко")
        self.assertEqual(item["names"]["uz_cyrl"], "Олма")

    def test_update_is_persisted(self) -> None:
        result = self.store.update_food(
            "olma",
            {
                "names": {
                    "uz_latn": "Olma",
                    "uz_cyrl": "Олма",
                    "ru": "Зелёное яблоко",
                    "en": "Green apple",
                },
                "category": "Mevalar",
            },
        )
        saved = json.loads(self.data_path.read_text(encoding="utf-8"))[0]
        self.assertEqual(saved["name_ru"], "Зелёное яблоко")
        self.assertEqual(result["names"]["en"], "Green apple")
        self.assertFalse(result["database_rebuilt"])

    def test_empty_translation_is_rejected(self) -> None:
        with self.assertRaises(ValidationError):
            self.store.update_food(
                "olma",
                {
                    "names": {
                        "uz_latn": "Olma",
                        "uz_cyrl": "Олма",
                        "ru": "",
                        "en": "Apple",
                    },
                    "category": "Mevalar",
                },
            )

    def test_delete_is_persisted(self) -> None:
        result = self.store.delete_food("olma")
        saved = json.loads(self.data_path.read_text(encoding="utf-8"))
        self.assertEqual(saved, [])
        self.assertTrue(result["deleted"])
        self.assertEqual(result["remaining"], 0)
        self.assertEqual(self.store.list_foods(), [])


if __name__ == "__main__":
    unittest.main()
