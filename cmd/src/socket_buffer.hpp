//-----------------------------------------------------------------------------
// Copyright 2024 Igor Spichkin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------------------

#pragma once

#include "socket.hpp"
#include <memory>

namespace btcmd
{

class CSocketBuffer final
{
  public:
    explicit CSocketBuffer( std::unique_ptr<ISocket>&& socket );

    /// \returns false if there is eof.
    bool Read( char* dst, size_t length ) noexcept;

    /// \returns false if there is eof.
    template <size_t Size>
    bool Read( std::array<char, Size>& buffer ) noexcept
    {
        return Read( buffer.data(), buffer.size() );
    }

  private:
    ptrdiff_t mCursor = 0;
    std::vector<char> mBuffer;
    std::unique_ptr<ISocket> mSocket;
};

} // namespace btcmd
