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

#include "socket.hpp"
#include <format>
#include <iostream>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <utility>

namespace btcmd
{

//-----------------------------------------------------------------------------
// CWSAGuard
//-----------------------------------------------------------------------------

CWSAGuard CWSAGuard::Create() noexcept
{
    return CWSAGuard{};
}

CWSAGuard::~CWSAGuard() = default;

//-----------------------------------------------------------------------------
// CUnixSocket
//-----------------------------------------------------------------------------

class CUnixSocket final : public ISocket
{
  public:
    explicit CUnixSocket( const int socket, addrinfo* addrInfo )
        : ISocket(), mSocket( socket ), mAddrInfo( addrInfo )
    {
    }

    CUnixSocket( CUnixSocket&& other ) noexcept
        : mSocket( std::exchange( other.mSocket, 0 ) ),
          mAddrInfo( std::exchange( other.mAddrInfo, nullptr ) )
    {
    }

    void Connect() const noexcept override
    {
        if ( connect( mSocket, mAddrInfo->ai_addr, mAddrInfo->ai_addrlen ) ==
             -1 )
        {
            std::cout << std::format( "connect error: {}\n", errno );

            std::exit( -1 );
        }
    }

    void Send( std::vector<char>& data ) const noexcept override
    {
        if ( send( mSocket, data.data(), data.size(), 0 ) == -1 )
        {
            std::cout << std::format( "send error: {}\n", errno );

            std::exit( -1 );
        }
    }

    size_t Recv( char* dst, int length ) const noexcept override
    {
        return recv( mSocket, dst, length, 0 );
    }

    ~CUnixSocket() override
    {
        if ( mAddrInfo != nullptr )
        {
            freeaddrinfo( std::exchange( mAddrInfo, nullptr ) );
        }

        if ( mSocket == 0 )
        {
            return;
        }

        if ( shutdown( mSocket, 0 ) == -1 )
        {
            std::cout << std::format( "shutdown error: {}\n", errno );

            std::exit( -1 );
        }
    }

  private:
    int mSocket;
    addrinfo* mAddrInfo;
};

[[nodiscard]] std::unique_ptr<ISocket>
CreateSocket( const std::string& node, const std::string& port ) noexcept
{
    addrinfo* addrInfo;

    if ( const auto error =
             getaddrinfo( node.c_str(), port.c_str(), nullptr, &addrInfo ) )
    {
        std::cout << std::format( "getaddrinfo error: {}\n", error );

        std::exit( -1 );
    }

    const auto sock = socket( addrInfo->ai_family, SOCK_STREAM, 0 );

    if ( sock == -1 )
    {
        std::cout << std::format( "Can't create a socket: error {}\n", errno );

        std::exit( -1 );
    }

    return std::make_unique<CUnixSocket>( sock, addrInfo );
}

} // namespace btcmd
