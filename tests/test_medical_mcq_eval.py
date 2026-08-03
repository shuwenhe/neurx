import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "posttrain"))
SCRIPT = ROOT / "posttrain" / "evaluate_medical_mcq.py"
SPEC = importlib.util.spec_from_file_location("evaluate_medical_mcq", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def scores(values):
    return [
        {"sum_log_probability": value, "mean_log_probability": value, "tokens": 1}
        for value in values
    ]


class MedicalMcqEvaluationTest(unittest.TestCase):
    def test_prediction_uses_highest_mean_log_probability(self):
        selected, confidence, margin = MODULE.prediction_from_scores(scores([-3.0, -1.0, -2.0, -4.0]))
        self.assertEqual(selected, 1)
        self.assertGreater(confidence, 0.5)
        self.assertEqual(margin, 1.0)

    def test_labeled_report_computes_accuracy_and_changes(self):
        record = {
            "id": "one",
            "question": "Question",
            "opa": "A1",
            "opb": "B1",
            "opc": "C1",
            "opd": "D1",
            "cop": 2,
            "subject_name": "Medicine",
        }
        report = MODULE.build_report(
            [record],
            scores([-1.0, -2.0, -3.0, -4.0]),
            scores([-2.0, -1.0, -3.0, -4.0]),
            Path("data.json"),
            Path("base"),
            Path("posttrain"),
        )
        metrics = report["metrics"]
        self.assertEqual(metrics["labeled_samples"], 1)
        self.assertEqual(metrics["changed_predictions"], 1)
        self.assertEqual(metrics["base_accuracy"], 0.0)
        self.assertEqual(metrics["posttrain_accuracy"], 1.0)


if __name__ == "__main__":
    unittest.main()
