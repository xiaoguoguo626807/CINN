#pragma once
#include <string>

#include "hlir/instruction/instruction.h"

namespace hlir {
namespace instruction {

class ParameterInstruction : public Instruction {
 public:
  ParameterInstruction(int param_offset, const std::string& name, const Shape& shape)
      : name_(name), Instruction(InstrCode::Parameter, shape), param_offset_(param_offset) {}

  std::string to_debug_string() override;

  const std::string& name() const { return name_; }

  std::string id() const override;

  int param_offset() const { return param_offset_; }

 private:
  std::string name_;
  int param_offset_{-1};
};

class CompareInstruction : public Instruction {
 public:
  CompareInstruction(const Shape& shape, Instruction* arg0, Instruction* arg1, CompareDirection direction)
      : Instruction(InstrCode::Compare, shape), direction_(direction) {
    AppendOperand(arg0);
    AppendOperand(arg1);
  }

 private:
  CompareDirection direction_;
};

class ReduceInstruction : public Instruction {
 public:
  ReduceInstruction(const Shape& shape,
                    Instruction* arg0,
                    Instruction* init_value,
                    const std::vector<int>& reduce_dimensions,
                    Computation* reduce_computation)
      : Instruction(InstrCode::Reduce, shape),
        init_value_(init_value),
        reduce_dimensions_(reduce_dimensions),
        reduce_computation_(reduce_computation) {
    AppendOperand(arg0);
    AppendOperand(init_value);
  }

 private:
  Instruction* init_value_{};
  std::vector<int> reduce_dimensions_;
  Computation* reduce_computation_{};
};

class BroadcastInstruction : public Instruction {
 public:
  BroadcastInstruction(const Shape& shape, const std::vector<int>& dimensions)
      : Instruction(InstrCode::Broadcast, shape), dimensions_(dimensions) {}

 private:
  std::vector<int> dimensions_;
};

class TransposeInstruction : public Instruction {
 public:
  TransposeInstruction(const Shape& shape, const std::vector<int>& dimensions)
      : Instruction(InstrCode::Transpose, shape), dimensions_(dimensions) {}

 private:
  std::vector<int> dimensions_;
};

class ConstantInstruction : public Instruction {
 public:
  ConstantInstruction(const Shape& shape, const std::vector<char>& data)
      : Instruction(InstrCode::Constant, shape), data_(data) {}

 private:
  std::vector<char> data_;
};

class CallInstruction : public Instruction {
 public:
  CallInstruction(Computation* computation,
                  const std::vector<Instruction*>& args,
                  const std::vector<Shape>& shapes,
                  const std::vector<std::string>& tensor_names,
                  const std::vector<cinn::common::Type>& types)
      : Instruction(InstrCode::Call, Shape{}), computation_(computation) {
    for (auto* arg : args) {
      AppendOperand(arg);
    }

    CHECK_EQ(tensor_names.size(), types.size());
    CHECK_EQ(shapes.size(), tensor_names.size());

    ret_tensor_names_ = tensor_names;
    ret_types_        = types;
    ret_shapes_       = shapes;
  }

  const std::vector<std::string>& ret_tensor_names() const { return ret_tensor_names_; }
  const std::vector<cinn::common::Type>& ret_types() const { return ret_types_; }
  const std::vector<Shape>& ret_shapes() const { return ret_shapes_; }

  const Computation* computation() const { return computation_; }

  std::string to_debug_string() override;

 private:
  std::vector<std::string> ret_tensor_names_;
  std::vector<cinn::common::Type> ret_types_;
  std::vector<Shape> ret_shapes_;

  Computation* computation_{};
};

class CustomCallInstruction : public Instruction {
 public:
  CustomCallInstruction(const Shape& shape,
                        const std::vector<Instruction*>& args,
                        const std::string& call_target,
                        const std::string& tag)
      : Instruction(InstrCode::CustomCall, shape), call_target_(call_target), args_(args) {}

 private:
  std::string call_target_;
  std::vector<Instruction*> args_;
};

/**
 * A tuple as the return values of a Call.
 */
class Tuple : public Instruction {
 public:
  explicit Tuple(const Instruction* call) : Instruction(InstrCode::Tuple, Shape{}), call_(call) {}
  explicit Tuple(const std::vector<const Instruction*>& items)
      : Instruction(InstrCode::Tuple, Shape{}), call_(nullptr), items_(items) {}

  std::unique_ptr<Instruction> Get(int i);

  const Instruction* call() const { return call_; }
  const std::vector<const Instruction*>& items() const { return items_; }

 private:
  const Instruction* call_;
  std::vector<const Instruction*> items_;
};

class TupleGet : public Instruction {
 public:
  explicit TupleGet(const Instruction* tuple, int offset)
      : Instruction(InstrCode::TupleGet, Shape{}), tuple_(tuple), offset_(offset) {
    CHECK_LE(offset, 0);

    auto* tuple_node = tuple->As<Tuple>();
    if (tuple_node->call()) {
      auto* call_node = tuple_node->call()->As<CallInstruction>();
      shape_          = call_node->ret_shapes()[offset];
      type_           = call_node->ret_types()[offset];
    } else if (!tuple_node->items().empty()) {
      shape_ = tuple_node->items()[offset]->shape();
      type_  = tuple_node->items()[offset]->type();
    } else {
      NOT_IMPLEMENTED
    }
  }

  const Tuple* tuple() const { return tuple_->As<Tuple>(); }
  int offset() const { return offset_; }

 private:
  const Instruction* tuple_{};
  int offset_{-1};
};

}  // namespace instruction
}  // namespace hlir