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

#include <memory>
#include <string>
#include <vector>

namespace btcmd
{

/// Windows only
class CWSAGuard final
{
  public:
    CWSAGuard( CWSAGuard& other ) = delete;
    CWSAGuard( CWSAGuard&& other ) = delete;

    CWSAGuard& operator=( CWSAGuard& other ) = delete;
    CWSAGuard& operator=( CWSAGuard&& other ) = delete;

    [[nodiscard]] static CWSAGuard Create() noexcept;

    ~CWSAGuard();

  private:
    CWSAGuard() = default;
};

class ISocket
{
  public:
    ISocket() = default;

    ISocket( ISocket& other ) = delete;
    ISocket& operator=( ISocket& other ) = delete;

    virtual void Connect() const noexcept = 0;

    virtual void Send( std::vector<char>& data ) const noexcept = 0;

    virtual size_t Recv( char* dst, int length ) const noexcept = 0;

    virtual ~ISocket() = default;
};

[[nodiscard]] std::unique_ptr<ISocket>
CreateSocket( const std::string& node, const std::string& port ) noexcept;

} // namespace btcmd
