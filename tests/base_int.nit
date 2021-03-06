# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2009 Jean Privat <jean@pryen.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import kernel

(-(1)).output
(2+3).output
(2-3).output
(2*3).output
(2/3).output
(2%3).output
'\n'.output

(3+2).output
(3-2).output
(3*2).output
(3/2).output
(3%2).output
'\n'.output

(not 1==2).output
(2==2).output
'\n'.output

(not 1.is_same_instance(2)).output
(2.is_same_instance(2)).output
'\n'.output

(not 1>2).output
(not 2>2).output
(3>2).output
'\n'.output

(not 1>=2).output
(2>=2).output
(3>=2).output
'\n'.output

(1<2).output
(not 2<2).output
(not 3<2).output
'\n'.output

(1<=2).output
(2<=2).output
(not 3<=2).output
'\n'.output

(not 1>=2).output
(2>=2).output
(3>=2).output
'\n'.output

(1<=>2).output
(2<=>2).output
(3<=>2).output
'\n'.output

1.succ.output
3.prec.output
