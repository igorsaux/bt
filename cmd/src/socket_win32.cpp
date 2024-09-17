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
#include <utility>
#include <winsock2.h>
#include <ws2tcpip.h>

namespace btcmd
{

//-----------------------------------------------------------------------------
// CWSAGuard
//-----------------------------------------------------------------------------

CWSAGuard CWSAGuard::Create() noexcept
{
    WSAData wsaData;

    if ( const auto error = WSAStartup( MAKEWORD( 2, 2 ), &wsaData );
         error != 0 )
    {
        std::cout << std::format( "WSAStartup error: {}\n", error );
        std::exit( -1 );
    }

    return CWSAGuard{};
}

CWSAGuard::~CWSAGuard()
{
    if ( const auto ok = WSACleanup(); ok != 0 )
    {
        const auto error = WSAGetLastError();

        std::cout << std::format( "WSACleanup error: {}\n", error );
        std::exit( -1 );
    }
}

//-----------------------------------------------------------------------------
// CWin32Socket
//-----------------------------------------------------------------------------

class CWin32Socket final : public ISocket
{
  public:
    explicit CWin32Socket( const SOCKET socket, ADDRINFOA* addrInfo )
        : ISocket(), mSocket( socket ), mAddrInfo( addrInfo )
    {
    }

    CWin32Socket( CWin32Socket&& other ) noexcept
        : mSocket( std::exchange( other.mSocket, 0 ) ),
          mAddrInfo( std::exchange( other.mAddrInfo, nullptr ) )
    {
    }

    CWin32Socket& operator=( CWin32Socket&& other ) noexcept
    {
        std::swap( mSocket, other.mSocket );

        return *this;
    }

    void Connect() const noexcept override
    {
        if ( WSAConnect( mSocket, mAddrInfo->ai_addr,
                         static_cast<int>( mAddrInfo->ai_addrlen ), nullptr,
                         nullptr, nullptr, nullptr ) )
        {
            std::cout << std::format( "WSAConnect error: {}\n",
                                      WSAGetLastError() );

            std::exit( -1 );
        }
    }

    void Send( std::vector<char>& data ) const noexcept override
    {
        WSABUF buffer{ .len = static_cast<ULONG>( data.size() ),
                       .buf = data.data() };
        DWORD bytesSend;

        if ( WSASend( mSocket, &buffer, 1, &bytesSend, 0, nullptr, nullptr ) )
        {
            std::cout << std::format( "send error: {}\n", WSAGetLastError() );

            std::exit( -1 );
        }
    }

    size_t Recv( char* dst, const int length ) const noexcept override
    {
        return recv( mSocket, dst, length, 0 );
    }

    ~CWin32Socket() override
    {
        if ( mAddrInfo != nullptr )
        {
            freeaddrinfo( std::exchange( mAddrInfo, nullptr ) );
        }

        if ( mSocket != 0 )
        {
            return;
        }

        if ( closesocket( mSocket ) )
        {
            std::cout << std::format( "closesocket error: {}\n",
                                      WSAGetLastError() );

            std::exit( -1 );
        }
    }

  private:
    SOCKET mSocket;
    PADDRINFOA mAddrInfo;
};

[[nodiscard]] std::unique_ptr<ISocket>
CreateSocket( const std::string& node, const std::string& port ) noexcept
{
    PADDRINFOA addrInfo;

    if ( const auto error =
             getaddrinfo( node.c_str(), port.c_str(), nullptr, &addrInfo ) )
    {
        std::cout << std::format( "getaddrinfo error: {} ({})\n",
                                  gai_strerror( error ), WSAGetLastError() );

        std::exit( -1 );
    }

    const auto socket =
        WSASocketW( addrInfo->ai_family, SOCK_STREAM, IPPROTO_TCP, nullptr, 0,
                    WSA_FLAG_OVERLAPPED );

    if ( socket == INVALID_SOCKET )
    {
        std::cout << std::format( "Can't create a socket: error {}\n",
                                  WSAGetLastError() );

        std::exit( -1 );
    }

    return std::make_unique<CWin32Socket>( socket, addrInfo );
}

} // namespace btcmd
