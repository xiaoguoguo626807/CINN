#pragma once
#include "cinn/ir/ir.h"

namespace cinn {
namespace optim {

Expr Optimize(Expr e, bool runtime_debug_info = false);

}  // namespace optim
}  // namespace cinn
