import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "posttrain" / "trainer" / "train_sft.py"
SPEC = importlib.util.spec_from_file_location("train_sft", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class FakeTokenizer:
    chat_template = None
    eos_token_id = 99

    def __call__(self, text, add_special_tokens):
        prefix = [1] if add_special_tokens else []
        return {"input_ids": prefix + [2 + index for index, _ in enumerate(text.split())]}


class FakeChatTokenizer(FakeTokenizer):
    chat_template = "template"

    def apply_chat_template(self, messages, tokenize, add_generation_prompt):
        ids = [10, 11]
        for message in messages:
            ids.extend([20 if message["role"] == "user" else 30, len(message["content"])])
        if add_generation_prompt:
            ids.append(30)
        return {"input_ids": ids, "attention_mask": [1] * len(ids)}


class PosttrainDataTest(unittest.TestCase):
    def test_medical_record_masks_prompt(self):
        record = {
            "question": "Which vitamin?",
            "opa": "A",
            "opb": "B12",
            "opc": "C",
            "opd": "D",
            "cop": 2,
            "exp": "Only animal products supply it.",
        }
        example = MODULE.encode_record(FakeTokenizer(), record, 128)
        self.assertIsNotNone(example)
        self.assertIn(99, example.labels)
        self.assertGreater(sum(label == MODULE.IGNORE_INDEX for label in example.labels), 0)
        self.assertGreater(sum(label != MODULE.IGNORE_INDEX for label in example.labels), 1)

    def test_pretokenized_record_preserves_response(self):
        record = {"input_ids": list(range(10)), "labels": [-100] * 6 + list(range(6, 10))}
        example = MODULE.encode_record(FakeTokenizer(), record, 6)
        self.assertEqual(example.input_ids, [4, 5, 6, 7, 8, 9])
        self.assertEqual(example.labels, [-100, -100, 6, 7, 8, 9])

    def test_chat_template_batch_encoding_is_supported(self):
        record = {"instruction": "Question", "output": "Answer"}
        example = MODULE.encode_record(FakeChatTokenizer(), record, 128)
        self.assertIsNotNone(example)
        self.assertGreater(sum(label == MODULE.IGNORE_INDEX for label in example.labels), 0)
        self.assertGreater(sum(label != MODULE.IGNORE_INDEX for label in example.labels), 0)

    def test_jsonl_and_json_array_are_streamed(self):
        records = [{"input_ids": [1, 2], "labels": [-100, 2]}, {"input_ids": [3, 4], "labels": [-100, 4]}]
        with tempfile.TemporaryDirectory() as directory:
            jsonl = Path(directory) / "data.jsonl"
            jsonl.write_text("\n".join(json.dumps(item) for item in records), encoding="utf-8")
            array = Path(directory) / "data.json"
            array.write_text(json.dumps(records), encoding="utf-8")
            self.assertEqual(list(MODULE.iter_json_records(jsonl)), records)
            self.assertEqual(list(MODULE.iter_json_records(array)), records)


if __name__ == "__main__":
    unittest.main()
